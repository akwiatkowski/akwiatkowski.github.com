function initApp() {
    const { useState, useEffect, useRef, useCallback } = window.React;
    const { render } = window.ReactDOM;

    const CONFIG = {
        bounds: {
            north: 54.8,
            south: 49.0,
            east: 24.0,
            west: 14.0
        },
        minZoom: 6,
        maxZoom: 16,
        validZooms: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
        maxPhotosOnMap: 100,
        maxPhotosInSidebar: 40,
        minPhotosOnMapDistance: 40.0,
        tileServer: '/tiles/ump/{z}/{x}/{y}.png',
        tileAttribution: '\u00a9 mapa UMP',
        intervalFromStart: (Date.now() - new Date('2011-01-01')),
    };

    const generateSamplePhotos = (rawPhotos) => {
        return rawPhotos.map((photo, idx) => {
            let lat = photo['exif.lat'];
            let lon = photo['exif.lon'];

            if (!lat || !lon) {
                const sampleCoords = [
                    [50.0635, 19.9450],
                    [50.0472, 19.9427],
                    [49.8499, 19.0451],
                    [50.2640, 19.0213],
                    [49.6992, 20.0663]
                ];
                const coord = sampleCoords[idx % sampleCoords.length];
                lat = coord[0];
                lon = coord[1];
            }

            return {
                ...photo,
                'exif.lat': lat,
                'exif.lon': lon,
                id: `${photo.post_slug}-${idx}`
            };
        });
    };

    const calculatePhotoValue = (photo) => {
        const photoDate = new Date(photo.time);
        const now = Date.now();
        const intervalScore = (now - photoDate) / CONFIG.intervalFromStart;
        const recencyScore = Math.sqrt(intervalScore);
        const tagScore = photo.points;

        return parseInt(recencyScore * tagScore);
    };

    const PhotoItem = ({ photo, onSelect }) => {
        const date = new Date(photo.time).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });

        return window.React.createElement('div',
            { className: 'photo-item', onClick: () => onSelect(photo) },
            window.React.createElement('img', {
                src: photo.grid_url || photo.article_url,
                alt: 'photo',
                className: 'photo-item-image',
                onError: (e) => e.target.style.display = 'none'
            }),
            window.React.createElement('div', { className: 'photo-item-overlay' },
                window.React.createElement('div', { className: 'photo-item-date' }, date),
                window.React.createElement('div', { className: 'photo-item-tags' },
                    (photo.tags || []).slice(0, 2).map(tag =>
                        window.React.createElement('span',
                            { key: tag, className: `tag-badge tag-${tag}` },
                            tag
                        )
                    )
                )
            )
        );
    };

    const PhotoModal = ({ photo, isOpen, onClose }) => {
        if (!isOpen || !photo) return null;

        const date = new Date(photo['exif.time'] || photo.time).toLocaleDateString('pl-PL', {
            year: 'numeric', month: 'long', day: 'numeric'
        });

        const metaParts = [date];
        if (photo['exif.camera_name']) metaParts.push(photo['exif.camera_name']);
        if (photo['exif.lens_name']) metaParts.push(photo['exif.lens_name']);
        if (photo['exif.altitude']) metaParts.push(photo['exif.altitude'].toFixed(0) + ' m n.p.m.');

        return window.React.createElement('div',
            { className: 'photo-lightbox', onClick: onClose },
            window.React.createElement('button', {
                className: 'photo-lightbox-close',
                onClick: onClose
            }, '\u00d7'),
            window.React.createElement('img', {
                src: photo.full_url,
                alt: photo.desc || '',
                className: 'photo-lightbox-image',
                onClick: (e) => e.stopPropagation(),
                onError: (e) => e.target.style.display = 'none'
            }),
            window.React.createElement('div', { className: 'photo-lightbox-caption' },
                photo.desc ? window.React.createElement('div', { className: 'photo-lightbox-desc' }, photo.desc) : null,
                window.React.createElement('div', { className: 'photo-lightbox-meta' },
                    metaParts.map((part, i) =>
                        window.React.createElement('span', { key: i }, part)
                    )
                ),
                (photo.tags || []).length > 0 ? window.React.createElement('div', { className: 'photo-lightbox-tags' },
                    photo.tags.map(tag =>
                        window.React.createElement('span', { key: tag, className: 'photo-lightbox-tag' }, tag)
                    )
                ) : null,
                photo.post_url ? window.React.createElement('a', {
                    href: photo.post_url,
                    target: '_blank',
                    rel: 'noopener noreferrer',
                    className: 'photo-lightbox-link',
                    onClick: (e) => e.stopPropagation()
                }, 'Zobacz wpis') : null
            )
        );
    };

    const MapComponent = ({ photos }) => {
        const mapRef = useRef(null);
        const mapInstanceRef = useRef(null);
        const markerGroupRef = useRef(null);
        const placedPixelsRef = useRef([]);
        const [visiblePhotos, setVisiblePhotos] = useState([]);
        const [selectedPhoto, setSelectedPhoto] = useState(null);
        const [isModalOpen, setIsModalOpen] = useState(false);

        const getMinDistanceToPlaced = useCallback((candX, candY) => {
          const placedPixels = placedPixelsRef.current;
          if (!placedPixels || placedPixels.length === 0) return Infinity;

          let minDist = Infinity;
          for (const placed of placedPixels) {
            const dx = candX - placed.x;
            const dy = candY - placed.y;
            const dist = Math.hypot(dx, dy);
            if (dist < minDist) minDist = dist;
          }
          return minDist;
        }, []);

        useEffect(() => {
            if (!mapRef.current) return;

            const map = L.map(mapRef.current, {
                maxBounds: L.latLngBounds(
                    [CONFIG.bounds.south, CONFIG.bounds.west],
                    [CONFIG.bounds.north, CONFIG.bounds.east]
                ),
                maxBoundsViscosity: 1.0,
                minZoom: CONFIG.minZoom,
                maxZoom: CONFIG.maxZoom
            }).setView(
                [(CONFIG.bounds.north + CONFIG.bounds.south) / 2,
                 (CONFIG.bounds.east + CONFIG.bounds.west) / 2],
                7
            );

            map.on('zoomend', () => {
                const currentZoom = map.getZoom();
                if (!CONFIG.validZooms.includes(currentZoom)) {
                    const closest = CONFIG.validZooms.reduce((prev, curr) =>
                        Math.abs(curr - currentZoom) < Math.abs(prev - currentZoom) ? curr : prev
                    );
                    map.setZoom(closest);
                }
            });

            L.tileLayer(CONFIG.tileServer, {
                attribution: CONFIG.tileAttribution,
                minZoom: CONFIG.minZoom,
                maxZoom: CONFIG.maxZoom
            }).addTo(map);

            mapInstanceRef.current = map;
            markerGroupRef.current = L.featureGroup().addTo(map);

            let usedPositions = {};
            const sortedPhotos = [...photos].sort((a, b) => calculatePhotoValue(b) - calculatePhotoValue(a));
            const debounceDelay = 300;
            let mapDebounceTimer = null;
            let sidebarDebounceTimer = null;

            const renderMapMarkers = () => {
                if (!markerGroupRef.current) return;
                markerGroupRef.current.clearLayers();
                usedPositions = {};
                let markerCount = 0;

                const bounds = mapInstanceRef.current.getBounds();
                placedPixelsRef.current = [];

                for (const photo of sortedPhotos) {
                    if (!photo['exif.lat'] || !photo['exif.lon']) continue;

                    const isInBounds = bounds.contains([photo['exif.lat'], photo['exif.lon']]);
                    if (!isInBounds) continue;

                    if (markerCount >= CONFIG.maxPhotosOnMap) break;

                    const minDist = 0.015;
                    const key = `${Math.round(photo['exif.lat'] / minDist) * minDist},${Math.round(photo['exif.lon'] / minDist) * minDist}`;

                    if (usedPositions[key]) continue;

                    const candidateLatLng = L.latLng(photo['exif.lat'], photo['exif.lon']);
                    const pixelPoint = mapInstanceRef.current.latLngToLayerPoint(candidateLatLng);
                    const { x: candX, y: candY } = pixelPoint;
                    const minDistance = getMinDistanceToPlaced(candX, candY);

                    if (minDistance <= CONFIG.minPhotosOnMapDistance) continue;

                    usedPositions[key] = true;
                    markerCount++;
                    placedPixelsRef.current.push({ x: candX, y: candY });

                    const markerHtml = `<img src="${photo.thumbnail_url || photo.article_url}" style="width:40px;height:40px;border-radius:2px;border:1px solid #fff;cursor:pointer;object-fit:cover;" onerror="this.style.display='none'"/>`;
                    const customIcon = L.divIcon({
                        html: markerHtml,
                        iconSize: [40, 40],
                        className: 'map-photo-marker'
                    });

                    const marker = L.marker(
                        [photo['exif.lat'], photo['exif.lon']],
                        { icon: customIcon }
                    )
                    marker.addTo(markerGroupRef.current);

                    marker.on('click', () => {
                        setSelectedPhoto(photo);
                        setIsModalOpen(true);
                    });
                }
            };

            const updateVisiblePhotos = () => {
                if (!mapInstanceRef.current) return;
                const bounds = mapInstanceRef.current.getBounds();
                const visible = sortedPhotos
                    .filter(photo => {
                        if (!photo['exif.lat'] || !photo['exif.lon']) return false;
                        return bounds.contains([photo['exif.lat'], photo['exif.lon']]);
                    });
                const limited = visible.slice(0, CONFIG.maxPhotosInSidebar);
                setVisiblePhotos(limited);
            };

            const debouncedMapUpdate = () => {
                if (mapDebounceTimer) clearTimeout(mapDebounceTimer);
                mapDebounceTimer = setTimeout(() => {
                    renderMapMarkers();
                }, debounceDelay);
            };

            const debouncedSidebarUpdate = () => {
                if (sidebarDebounceTimer) clearTimeout(sidebarDebounceTimer);
                sidebarDebounceTimer = setTimeout(() => {
                    updateVisiblePhotos();
                }, debounceDelay);
            };

            map.on('moveend', () => {
                debouncedMapUpdate();
                debouncedSidebarUpdate();
            });
            map.on('zoomend', () => {
                debouncedMapUpdate();
                debouncedSidebarUpdate();
            });

            renderMapMarkers();
            updateVisiblePhotos();

            return () => {
                clearTimeout(mapDebounceTimer);
                clearTimeout(sidebarDebounceTimer);
                map.remove();
            };
        }, [photos]);

        return window.React.createElement('div', { className: 'map-container' },
            window.React.createElement('div', { id: 'map', ref: mapRef }),
            window.React.createElement('div', { className: 'sidebar' },
                window.React.createElement('div', { className: 'sidebar-header' },
                    window.React.createElement('h3', null, 'Photos'),
                    window.React.createElement('small', null, `${visiblePhotos.length} visible in area`)
                ),
                window.React.createElement('div', { className: 'photos-grid' },
                    visiblePhotos.length > 0 ?
                        visiblePhotos.map(photo =>
                            window.React.createElement(PhotoItem, {
                                key: photo.id,
                                photo: photo,
                                onSelect: () => {
                                    setSelectedPhoto(photo);
                                    setIsModalOpen(true);
                                }
                            })
                        )
                    : window.React.createElement('div',
                        { style: { padding: '20px', color: '#999', textAlign: 'center' } },
                        'No photos in this area'
                    )
                )
            ),
            window.React.createElement(PhotoModal, {
                photo: selectedPhoto,
                isOpen: isModalOpen,
                onClose: () => setIsModalOpen(false)
            })
        );
    };

    const App = () => {
        const [photos, setPhotos] = useState(null);

        useEffect(() => {
            fetch('/jsons/photos_map.json')
                .then(res => res.json())
                .then(data => {
                    const processedPhotos = generateSamplePhotos(data.photos);
                    setPhotos(processedPhotos);
                })
                .catch(err => {
                    console.error('Error loading photos:', err);
                    setPhotos([]);
                });
        }, []);

        if (!photos) {
            return window.React.createElement('div', { className: 'loading' }, 'Loading photos...');
        }

        return window.React.createElement(MapComponent, { photos: photos });
    };

    render(React.createElement(App), document.getElementById('root'));
}

if (window.React && window.ReactDOM) {
    initApp();
} else {
    document.addEventListener('DOMContentLoaded', () => {
        setTimeout(initApp, 100);
    });
}
