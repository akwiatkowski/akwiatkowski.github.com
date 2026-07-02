package pipeline

import (
	"fmt"
	"os"
	"time"
)

// NodeFunc is a build step that receives the pipeline context.
type NodeFunc func(ctx *Context) error

// pipelineNode is a named build step with declared dependencies.
type pipelineNode struct {
	name string
	deps []string
	fn   NodeFunc
}

// Pipeline manages build steps with dependency tracking and executes them
// in topological order. Each node declares which other nodes must complete
// before it can run, and the pipeline resolves the correct execution order.
//
// All nodes receive the same Context, which includes the Force flag for
// controlling cache invalidation. Nodes should check ctx.Force to decide
// whether to regenerate existing outputs.
type Pipeline struct {
	nodes []pipelineNode
	index map[string]bool
}

// NewPipeline creates an empty pipeline.
func NewPipeline() *Pipeline {
	return &Pipeline{index: make(map[string]bool)}
}

// Add registers a named build step with its dependencies.
// Dependencies are names of other nodes that must complete before this one runs.
// Panics if a duplicate name is registered.
func (p *Pipeline) Add(name string, deps []string, fn NodeFunc) {
	if p.index[name] {
		panic(fmt.Sprintf("pipeline: duplicate node %q", name))
	}
	p.index[name] = true
	p.nodes = append(p.nodes, pipelineNode{name: name, deps: deps, fn: fn})
}

// Len returns the number of registered nodes.
func (p *Pipeline) Len() int {
	return len(p.nodes)
}

// Run executes all nodes in dependency order (topological sort).
// Prints timing per node when ctx.Verbose is true.
// Returns the first error encountered, wrapping it with the node name.
func (p *Pipeline) Run(ctx *Context) error {
	order, err := p.topoSort()
	if err != nil {
		return err
	}

	total := len(order)
	for i, node := range order {
		if total > 1 {
			fmt.Fprintf(os.Stderr, "\r\033[2K[%d/%d] %s...", i+1, total, node.name)
		}
		t0 := time.Now()
		if err := node.fn(ctx); err != nil {
			if total > 1 {
				fmt.Fprintln(os.Stderr)
			}
			return fmt.Errorf("%s: %w", node.name, err)
		}
		if ctx.Verbose {
			fmt.Printf("  [%s] %v\n", node.name, time.Since(t0))
		}
	}
	if total > 1 {
		fmt.Fprintf(os.Stderr, "\r\033[2K")
	}
	return nil
}

// topoSort returns nodes in topological order using Kahn's algorithm.
// Nodes with no unresolved dependencies are processed first. Among nodes
// at the same level, registration order is preserved for determinism.
func (p *Pipeline) topoSort() ([]pipelineNode, error) {
	// Validate all deps exist
	for _, node := range p.nodes {
		for _, dep := range node.deps {
			if !p.index[dep] {
				return nil, fmt.Errorf("node %q depends on unknown %q", node.name, dep)
			}
		}
	}

	byName := make(map[string]int, len(p.nodes))
	for i, node := range p.nodes {
		byName[node.name] = i
	}

	// Compute in-degree and build adjacency list
	inDegree := make(map[string]int, len(p.nodes))
	children := make(map[string][]string) // dep -> nodes that depend on it
	for _, node := range p.nodes {
		inDegree[node.name] += 0 // ensure entry exists
		for _, dep := range node.deps {
			inDegree[node.name]++
			children[dep] = append(children[dep], node.name)
		}
	}

	// Seed queue with zero-degree nodes (in registration order)
	var queue []string
	for _, node := range p.nodes {
		if inDegree[node.name] == 0 {
			queue = append(queue, node.name)
		}
	}

	var result []pipelineNode
	for len(queue) > 0 {
		name := queue[0]
		queue = queue[1:]
		result = append(result, p.nodes[byName[name]])

		for _, child := range children[name] {
			inDegree[child]--
			if inDegree[child] == 0 {
				queue = append(queue, child)
			}
		}
	}

	if len(result) != len(p.nodes) {
		return nil, fmt.Errorf("dependency cycle detected (%d of %d nodes resolved)",
			len(result), len(p.nodes))
	}

	return result, nil
}
