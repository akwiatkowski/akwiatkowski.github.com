package pipeline

import (
	"strings"
	"testing"
)

func TestNewGraphEmpty(t *testing.T) {
	g, err := NewGraph(nil)
	if err != nil {
		t.Fatal(err)
	}
	layers := g.Layers()
	if len(layers) != 0 {
		t.Errorf("expected 0 layers, got %d", len(layers))
	}
}

func TestNewGraphSingleNode(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
	}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}
	layers := g.Layers()
	if len(layers) != 1 {
		t.Fatalf("expected 1 layer, got %d", len(layers))
	}
	if layers[0][0].Name() != "a" {
		t.Errorf("expected node 'a'")
	}
}

func TestNewGraphLinearChain(t *testing.T) {
	// a → b → c (c depends on b, b depends on a)
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
		&SimpleNode{NodeName: "b", NodeDeps: []string{"a"}},
		&SimpleNode{NodeName: "c", NodeDeps: []string{"b"}},
	}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	layers := g.Layers()
	if len(layers) != 3 {
		t.Fatalf("expected 3 layers, got %d", len(layers))
	}
	if layers[0][0].Name() != "a" {
		t.Errorf("layer 0: expected 'a', got %q", layers[0][0].Name())
	}
	if layers[1][0].Name() != "b" {
		t.Errorf("layer 1: expected 'b', got %q", layers[1][0].Name())
	}
	if layers[2][0].Name() != "c" {
		t.Errorf("layer 2: expected 'c', got %q", layers[2][0].Name())
	}
}

func TestNewGraphParallelNodes(t *testing.T) {
	// a, b, c all independent → single layer
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
		&SimpleNode{NodeName: "b"},
		&SimpleNode{NodeName: "c"},
	}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	layers := g.Layers()
	if len(layers) != 1 {
		t.Fatalf("expected 1 layer, got %d", len(layers))
	}
	if len(layers[0]) != 3 {
		t.Errorf("expected 3 nodes in layer, got %d", len(layers[0]))
	}
}

func TestNewGraphDiamond(t *testing.T) {
	// Diamond: a → b, a → c, b → d, c → d
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
		&SimpleNode{NodeName: "b", NodeDeps: []string{"a"}},
		&SimpleNode{NodeName: "c", NodeDeps: []string{"a"}},
		&SimpleNode{NodeName: "d", NodeDeps: []string{"b", "c"}},
	}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	layers := g.Layers()
	if len(layers) != 3 {
		t.Fatalf("expected 3 layers, got %d", len(layers))
	}
	if len(layers[0]) != 1 {
		t.Errorf("layer 0: expected 1 node, got %d", len(layers[0]))
	}
	if len(layers[1]) != 2 {
		t.Errorf("layer 1: expected 2 nodes, got %d", len(layers[1]))
	}
	if len(layers[2]) != 1 {
		t.Errorf("layer 2: expected 1 node, got %d", len(layers[2]))
	}
}

func TestNewGraphCycleDetection(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a", NodeDeps: []string{"b"}},
		&SimpleNode{NodeName: "b", NodeDeps: []string{"a"}},
	}
	_, err := NewGraph(nodes)
	if err == nil {
		t.Fatal("expected cycle error")
	}
	if !strings.Contains(err.Error(), "cycle") {
		t.Errorf("expected cycle error, got: %v", err)
	}
}

func TestNewGraphSelfCycle(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a", NodeDeps: []string{"a"}},
	}
	_, err := NewGraph(nodes)
	if err == nil {
		t.Fatal("expected cycle error for self-dependency")
	}
}

func TestNewGraphMissingDependency(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a", NodeDeps: []string{"missing"}},
	}
	_, err := NewGraph(nodes)
	if err == nil {
		t.Fatal("expected missing dependency error")
	}
	if !strings.Contains(err.Error(), "missing") {
		t.Errorf("expected 'missing' in error, got: %v", err)
	}
}

func TestNewGraphDuplicateNode(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
		&SimpleNode{NodeName: "a"},
	}
	_, err := NewGraph(nodes)
	if err == nil {
		t.Fatal("expected duplicate error")
	}
	if !strings.Contains(err.Error(), "duplicate") {
		t.Errorf("expected 'duplicate' in error, got: %v", err)
	}
}

func TestGraphNodeLookup(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a"},
		&SimpleNode{NodeName: "b"},
	}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	if n := g.Node("a"); n == nil || n.Name() != "a" {
		t.Error("expected to find node 'a'")
	}
	if n := g.Node("nonexistent"); n != nil {
		t.Error("expected nil for nonexistent node")
	}
}

func TestNewGraphThreeNodeCycle(t *testing.T) {
	nodes := []Node{
		&SimpleNode{NodeName: "a", NodeDeps: []string{"c"}},
		&SimpleNode{NodeName: "b", NodeDeps: []string{"a"}},
		&SimpleNode{NodeName: "c", NodeDeps: []string{"b"}},
	}
	_, err := NewGraph(nodes)
	if err == nil {
		t.Fatal("expected cycle error")
	}
}
