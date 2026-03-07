package pipeline

import (
	"fmt"
	"sync"
	"time"
)

// RunStatus describes the outcome of a node execution.
type RunStatus string

const (
	StatusRan     RunStatus = "ran"
	StatusSkipped RunStatus = "skipped"
	StatusError   RunStatus = "error"
	StatusDryRun  RunStatus = "dry-run"
)

// RunResult holds the outcome of executing a single node.
type RunResult struct {
	NodeName string
	Status   RunStatus
	Duration time.Duration
	Err      error
}

// Run executes the pipeline graph respecting dependencies and parallelism.
// Nodes within the same layer run in parallel, bounded by ctx.Workers.
// Execution stops on the first error (fail-fast).
func Run(g *Graph, ctx *Context) ([]RunResult, error) {
	layers := g.Layers()
	var allResults []RunResult

	workers := ctx.Workers
	if workers <= 0 {
		workers = 1
	}

	for _, layer := range layers {
		results, err := runLayer(layer, ctx, workers)
		allResults = append(allResults, results...)
		if err != nil {
			return allResults, err
		}
	}

	return allResults, nil
}

func runLayer(nodes []Node, ctx *Context, workers int) ([]RunResult, error) {
	results := make([]RunResult, len(nodes))
	errCh := make(chan error, 1) // buffer 1 to avoid goroutine leak
	sem := make(chan struct{}, workers)

	var wg sync.WaitGroup
	for i, node := range nodes {
		wg.Add(1)
		go func(idx int, n Node) {
			defer wg.Done()

			// Check for early abort from another goroutine
			select {
			case <-errCh:
				// Re-send so other goroutines also see it
				errCh <- fmt.Errorf("aborted")
				results[idx] = RunResult{NodeName: n.Name(), Status: StatusSkipped}
				return
			default:
			}

			sem <- struct{}{} // acquire worker slot
			defer func() { <-sem }()

			result := runNode(n, ctx)
			results[idx] = result

			if result.Err != nil {
				select {
				case errCh <- result.Err:
				default:
				}
			}
		}(i, node)
	}
	wg.Wait()

	// Check if any node errored
	select {
	case err := <-errCh:
		return results, err
	default:
		return results, nil
	}
}

func runNode(n Node, ctx *Context) RunResult {
	start := time.Now()

	if !ctx.Force {
		stale, err := n.IsStale(ctx)
		if err != nil {
			return RunResult{
				NodeName: n.Name(),
				Status:   StatusError,
				Duration: time.Since(start),
				Err:      fmt.Errorf("staleness check for %q: %w", n.Name(), err),
			}
		}
		if !stale {
			return RunResult{
				NodeName: n.Name(),
				Status:   StatusSkipped,
				Duration: time.Since(start),
			}
		}
	}

	if ctx.DryRun {
		return RunResult{
			NodeName: n.Name(),
			Status:   StatusDryRun,
			Duration: time.Since(start),
		}
	}

	err := n.Run(ctx)
	status := StatusRan
	if err != nil {
		status = StatusError
	}

	return RunResult{
		NodeName: n.Name(),
		Status:   status,
		Duration: time.Since(start),
		Err:      err,
	}
}
