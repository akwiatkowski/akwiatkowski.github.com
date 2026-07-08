package terrain

import (
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// nmtNoData is the fill value used in the GUGiK 10m tiles for pixels without a
// measurement. It must be flagged so GDAL ignores it when mosaicking/shading.
const nmtNoData = -32768

// nmtSidecar is the per-tile JSON georeferencing that accompanies each raw
// int16 elevation grid. Values are decimeters (elevation = raw * scale).
type nmtSidecar struct {
	MinLon float64 `json:"min_lon"`
	MaxLat float64 `json:"max_lat"`
	Nx     int     `json:"nx"`
	Ny     int     `json:"ny"`
	Xstep  float64 `json:"xstep"`
	Ystep  float64 `json:"ystep"`
	Scale  float64 `json:"scale"`
}

// nmtTilesFor returns the .i16.gz paths of the GUGiK 10m tiles whose nominal
// grid cell intersects the lat/lon bounding box. The cell is read from the
// filename (dtm_<lat0>_<lon0>_<lat1>_<lon1>_10m.i16.gz).
func nmtTilesFor(latMin, latMax, lonMin, lonMax float64, dtmDir string) []string {
	entries, err := os.ReadDir(dtmDir)
	if err != nil {
		return nil
	}
	var tiles []string
	for _, e := range entries {
		name := e.Name()
		if !strings.HasSuffix(name, ".i16.gz") {
			continue
		}
		lat0, lon0, lat1, lon1, ok := parseNMTName(name)
		if !ok {
			continue
		}
		// Reject tiles whose cell does not overlap the query box.
		if lat1 < latMin || lat0 > latMax || lon1 < lonMin || lon0 > lonMax {
			continue
		}
		tiles = append(tiles, filepath.Join(dtmDir, name))
	}
	return tiles
}

// parseNMTName extracts the nominal SW/NE corners from a tile filename.
func parseNMTName(name string) (lat0, lon0, lat1, lon1 float64, ok bool) {
	// dtm_53.4000_18.6000_53.5000_18.7000_10m.i16.gz
	parts := strings.Split(name, "_")
	if len(parts) < 5 || parts[0] != "dtm" {
		return 0, 0, 0, 0, false
	}
	var err error
	if lat0, err = strconv.ParseFloat(parts[1], 64); err != nil {
		return 0, 0, 0, 0, false
	}
	if lon0, err = strconv.ParseFloat(parts[2], 64); err != nil {
		return 0, 0, 0, 0, false
	}
	if lat1, err = strconv.ParseFloat(parts[3], 64); err != nil {
		return 0, 0, 0, 0, false
	}
	if lon1, err = strconv.ParseFloat(parts[4], 64); err != nil {
		return 0, 0, 0, 0, false
	}
	return lat0, lon0, lat1, lon1, true
}

// buildNMT10VRT decompresses each covering 10m tile to a raw file and writes a
// GDAL VRT (raw raster band) georeferenced from its sidecar, then mosaics them
// into a single VRT GDAL can warp. Returns the mosaic path and the elevation
// scale (decimeters→meters) to fold into the hillshade z-factor.
func buildNMT10VRT(tiles []string, tmpDir string) (mosaic string, scale float64, err error) {
	var tileVRTs []string
	scale = 0.1 // default; overwritten from sidecar below
	for i, gzPath := range tiles {
		side := strings.TrimSuffix(gzPath, ".i16.gz") + ".json"
		meta, err := readNMTSidecar(side)
		if err != nil {
			return "", 0, err
		}
		if meta.Scale != 0 {
			scale = meta.Scale
		}

		rawPath := filepath.Join(tmpDir, fmt.Sprintf("nmt_%d.i16", i))
		// Expected decompressed size: nx*ny int16 samples. Bounding the copy to
		// this both guards against a decompression bomb and validates the tile.
		maxBytes := int64(meta.Nx) * int64(meta.Ny) * 2
		if err := gunzipTo(gzPath, rawPath, maxBytes); err != nil {
			return "", 0, err
		}
		vrtPath := filepath.Join(tmpDir, fmt.Sprintf("nmt_%d.vrt", i))
		if err := writeRawVRT(vrtPath, rawPath, meta); err != nil {
			return "", 0, err
		}
		tileVRTs = append(tileVRTs, vrtPath)
	}
	if len(tileVRTs) == 0 {
		return "", 0, fmt.Errorf("no 10m tiles to mosaic")
	}

	mosaic = filepath.Join(tmpDir, "nmt_mosaic.vrt")
	if err := runTool("gdalbuildvrt", append([]string{"-srcnodata", strconv.Itoa(nmtNoData), mosaic}, tileVRTs...)...); err != nil {
		return "", 0, err
	}
	return mosaic, scale, nil
}

// readNMTSidecar loads and validates a tile's JSON georeferencing.
func readNMTSidecar(path string) (nmtSidecar, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nmtSidecar{}, fmt.Errorf("read NMT sidecar %s: %w", path, err)
	}
	var m nmtSidecar
	if err := json.Unmarshal(raw, &m); err != nil {
		return nmtSidecar{}, fmt.Errorf("parse NMT sidecar %s: %w", path, err)
	}
	if m.Nx <= 0 || m.Ny <= 0 {
		return nmtSidecar{}, fmt.Errorf("invalid NMT sidecar %s: nx=%d ny=%d", path, m.Nx, m.Ny)
	}
	return m, nil
}

// gunzipTo decompresses src (.gz) into dst, refusing to write more than
// maxBytes (guards against a decompression bomb; maxBytes is the tile's known
// uncompressed size).
func gunzipTo(src, dst string, maxBytes int64) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	gz, err := gzip.NewReader(in)
	if err != nil {
		return fmt.Errorf("gunzip %s: %w", src, err)
	}
	defer gz.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	// LimitReader to maxBytes+1 so an oversized stream is detected rather than
	// silently truncated.
	n, err := io.Copy(out, io.LimitReader(gz, maxBytes+1))
	if err != nil {
		return fmt.Errorf("decompress %s: %w", src, err)
	}
	if n > maxBytes {
		return fmt.Errorf("decompressed %s exceeds expected size %d bytes", src, maxBytes)
	}
	return nil
}

// gunzipBytes decompresses src (.gz) fully into memory, refusing to read more
// than maxBytes (decompression-bomb guard; maxBytes is the known raw size).
func gunzipBytes(src string, maxBytes int64) ([]byte, error) {
	in, err := os.Open(src)
	if err != nil {
		return nil, err
	}
	defer in.Close()
	gz, err := gzip.NewReader(in)
	if err != nil {
		return nil, fmt.Errorf("gunzip %s: %w", src, err)
	}
	defer gz.Close()
	data, err := io.ReadAll(io.LimitReader(gz, maxBytes+1))
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", src, err)
	}
	if int64(len(data)) > maxBytes {
		return nil, fmt.Errorf("decompressed %s exceeds expected size %d bytes", src, maxBytes)
	}
	return data, nil
}

// writeRawVRT writes a VRT describing a headerless little-endian int16 grid so
// GDAL can read it. The geotransform places the top-left pixel at
// (min_lon, max_lat) with degree-sized steps in WGS84.
func writeRawVRT(vrtPath, rawPath string, m nmtSidecar) error {
	// GeoTransform: originX, pixelW, 0, originY, 0, pixelH (negative: north-up).
	gt := fmt.Sprintf("%.12f, %.12g, 0, %.12f, 0, %.12g", m.MinLon, m.Xstep, m.MaxLat, -m.Ystep)
	lineOffset := m.Nx * 2 // 2 bytes per int16 sample
	vrt := fmt.Sprintf(`<VRTDataset rasterXSize="%d" rasterYSize="%d">
  <SRS>EPSG:4326</SRS>
  <GeoTransform>%s</GeoTransform>
  <VRTRasterBand dataType="Int16" band="1" subClass="VRTRawRasterBand">
    <SourceFilename relativeToVRT="0">%s</SourceFilename>
    <ImageOffset>0</ImageOffset>
    <PixelOffset>2</PixelOffset>
    <LineOffset>%d</LineOffset>
    <ByteOrder>LSB</ByteOrder>
    <NoDataValue>%d</NoDataValue>
  </VRTRasterBand>
</VRTDataset>`, m.Nx, m.Ny, gt, rawPath, lineOffset, nmtNoData)
	if err := os.WriteFile(vrtPath, []byte(vrt), 0o644); err != nil {
		return fmt.Errorf("write raw VRT: %w", err)
	}
	return nil
}
