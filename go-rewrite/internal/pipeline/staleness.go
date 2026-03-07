package pipeline

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"time"
)

// MaxMtime returns the most recent modification time among the given paths.
// Non-existent files are skipped. Returns zero time if no files exist.
func MaxMtime(paths ...string) (time.Time, error) {
	var max time.Time
	for _, p := range paths {
		info, err := os.Stat(p)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return time.Time{}, err
		}
		if t := info.ModTime(); t.After(max) {
			max = t
		}
	}
	return max, nil
}

// FileNewerThan returns true if source is newer than target.
// Returns true if target does not exist (needs rebuild).
// Returns false if source does not exist.
func FileNewerThan(source, target string) (bool, error) {
	srcInfo, err := os.Stat(source)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	tgtInfo, err := os.Stat(target)
	if errors.Is(err, fs.ErrNotExist) {
		return true, nil
	}
	if err != nil {
		return false, err
	}

	return srcInfo.ModTime().After(tgtInfo.ModTime()), nil
}

// AnyNewerThan returns true if any of the source files is newer than target.
// Returns true if target does not exist.
func AnyNewerThan(sources []string, target string) (bool, error) {
	tgtInfo, err := os.Stat(target)
	if errors.Is(err, fs.ErrNotExist) {
		return true, nil
	}
	if err != nil {
		return false, err
	}
	tgtTime := tgtInfo.ModTime()

	for _, src := range sources {
		info, err := os.Stat(src)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return false, err
		}
		if info.ModTime().After(tgtTime) {
			return true, nil
		}
	}
	return false, nil
}

// GlobNewerThan returns true if any file matching the glob pattern is newer than target.
// Returns true if target does not exist.
func GlobNewerThan(pattern string, target string) (bool, error) {
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return false, err
	}
	return AnyNewerThan(matches, target)
}
