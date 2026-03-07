package pipeline

import "fmt"

// Graph represents a directed acyclic graph of pipeline nodes.
type Graph struct {
	nodes map[string]Node
	edges map[string][]string // node name → dependency names
}

// NewGraph builds a Graph from a slice of nodes.
// Returns an error if there are duplicate names, missing dependencies, or cycles.
func NewGraph(nodes []Node) (*Graph, error) {
	g := &Graph{
		nodes: make(map[string]Node, len(nodes)),
		edges: make(map[string][]string, len(nodes)),
	}

	for _, n := range nodes {
		name := n.Name()
		if _, exists := g.nodes[name]; exists {
			return nil, fmt.Errorf("duplicate node: %q", name)
		}
		g.nodes[name] = n
		g.edges[name] = n.Deps()
	}

	// Validate all dependencies exist
	for name, deps := range g.edges {
		for _, dep := range deps {
			if _, exists := g.nodes[dep]; !exists {
				return nil, fmt.Errorf("node %q depends on unknown node %q", name, dep)
			}
		}
	}

	// Check for cycles using topological sort
	if _, err := g.topoSort(); err != nil {
		return nil, err
	}

	return g, nil
}

// Layers returns nodes grouped into execution layers using Kahn's algorithm.
// Each layer contains nodes whose dependencies are all in earlier layers,
// meaning nodes within a layer can execute in parallel.
func (g *Graph) Layers() [][]Node {
	layers, _ := g.topoSort()
	return layers
}

// Node returns a node by name, or nil if not found.
func (g *Graph) Node(name string) Node {
	return g.nodes[name]
}

// topoSort performs Kahn's algorithm and returns layers of nodes.
// Returns an error if a cycle is detected.
func (g *Graph) topoSort() ([][]Node, error) {
	// Build in-degree map (count of dependencies per node)
	inDegree := make(map[string]int, len(g.nodes))
	// Build reverse edges: dep → nodes that depend on it
	dependents := make(map[string][]string, len(g.nodes))

	for name := range g.nodes {
		inDegree[name] = 0
	}
	for name, deps := range g.edges {
		inDegree[name] = len(deps)
		for _, dep := range deps {
			dependents[dep] = append(dependents[dep], name)
		}
	}

	// Find initial layer: nodes with no dependencies
	var current []string
	for name, deg := range inDegree {
		if deg == 0 {
			current = append(current, name)
		}
	}

	var layers [][]Node
	processed := 0

	for len(current) > 0 {
		// Build this layer's node list
		layer := make([]Node, len(current))
		for i, name := range current {
			layer[i] = g.nodes[name]
		}
		layers = append(layers, layer)
		processed += len(current)

		// Find next layer
		var next []string
		for _, name := range current {
			for _, dep := range dependents[name] {
				inDegree[dep]--
				if inDegree[dep] == 0 {
					next = append(next, dep)
				}
			}
		}
		current = next
	}

	if processed != len(g.nodes) {
		return nil, fmt.Errorf("cycle detected in pipeline graph")
	}

	return layers, nil
}
