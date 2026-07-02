package pipeline

import (
	"fmt"
	"sync/atomic"
	"testing"
	"time"
)

func TestRunSimple(t *testing.T) {
	var order []string
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			RunFn:    func(ctx *Context) error { order = append(order, "a"); return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].Status != StatusRan {
		t.Errorf("expected status 'ran', got %q", results[0].Status)
	}
	if len(order) != 1 || order[0] != "a" {
		t.Errorf("expected [a], got %v", order)
	}
}

func TestRunDependencyOrder(t *testing.T) {
	var order []string
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			RunFn:    func(ctx *Context) error { order = append(order, "a"); return nil },
		},
		&SimpleNode{
			NodeName: "b",
			NodeDeps: []string{"a"},
			RunFn:    func(ctx *Context) error { order = append(order, "b"); return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
	if len(order) != 2 || order[0] != "a" || order[1] != "b" {
		t.Errorf("expected [a, b], got %v", order)
	}
}

func TestRunSkipFreshNodes(t *testing.T) {
	ran := false
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			StaleFn:  func(ctx *Context) (bool, error) { return false, nil },
			RunFn:    func(ctx *Context) error { ran = true; return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if ran {
		t.Error("fresh node should not have run")
	}
	if results[0].Status != StatusSkipped {
		t.Errorf("expected status 'skipped', got %q", results[0].Status)
	}
}

func TestRunForceMode(t *testing.T) {
	ran := false
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			StaleFn:  func(ctx *Context) (bool, error) { return false, nil },
			RunFn:    func(ctx *Context) error { ran = true; return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1, Force: true}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if !ran {
		t.Error("force mode should run even fresh nodes")
	}
	if results[0].Status != StatusRan {
		t.Errorf("expected status 'ran', got %q", results[0].Status)
	}
}

func TestRunDryRun(t *testing.T) {
	ran := false
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			RunFn:    func(ctx *Context) error { ran = true; return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1, DryRun: true}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if ran {
		t.Error("dry-run should not execute node")
	}
	if results[0].Status != StatusDryRun {
		t.Errorf("expected status 'dry-run', got %q", results[0].Status)
	}
}

func TestRunErrorPropagation(t *testing.T) {
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			RunFn:    func(ctx *Context) error { return fmt.Errorf("boom") },
		},
		&SimpleNode{
			NodeName: "b",
			NodeDeps: []string{"a"},
			RunFn:    func(ctx *Context) error { return nil },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	_, err = Run(g, ctx)
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestRunParallel(t *testing.T) {
	// Two independent nodes should run concurrently
	var running atomic.Int32
	var maxRunning atomic.Int32

	makeNode := func(name string) Node {
		return &SimpleNode{
			NodeName: name,
			RunFn: func(ctx *Context) error {
				cur := running.Add(1)
				// Track max concurrency
				for {
					old := maxRunning.Load()
					if cur <= old || maxRunning.CompareAndSwap(old, cur) {
						break
					}
				}
				time.Sleep(20 * time.Millisecond)
				running.Add(-1)
				return nil
			},
		}
	}

	nodes := []Node{makeNode("a"), makeNode("b"), makeNode("c"), makeNode("d")}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 4}
	_, err = Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if maxRunning.Load() < 2 {
		t.Errorf("expected at least 2 concurrent nodes, got max %d", maxRunning.Load())
	}
}

func TestRunWorkerBound(t *testing.T) {
	// With workers=1, only 1 node should run at a time
	var running atomic.Int32
	var maxRunning atomic.Int32

	makeNode := func(name string) Node {
		return &SimpleNode{
			NodeName: name,
			RunFn: func(ctx *Context) error {
				cur := running.Add(1)
				for {
					old := maxRunning.Load()
					if cur <= old || maxRunning.CompareAndSwap(old, cur) {
						break
					}
				}
				time.Sleep(5 * time.Millisecond)
				running.Add(-1)
				return nil
			},
		}
	}

	nodes := []Node{makeNode("a"), makeNode("b"), makeNode("c")}
	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	_, err = Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if maxRunning.Load() > 1 {
		t.Errorf("expected max 1 concurrent with workers=1, got %d", maxRunning.Load())
	}
}

func TestRunDuration(t *testing.T) {
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			RunFn: func(ctx *Context) error {
				time.Sleep(10 * time.Millisecond)
				return nil
			},
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}

	if results[0].Duration < 10*time.Millisecond {
		t.Errorf("expected duration >= 10ms, got %v", results[0].Duration)
	}
}

func TestRunStalenessFnError(t *testing.T) {
	nodes := []Node{
		&SimpleNode{
			NodeName: "a",
			StaleFn:  func(ctx *Context) (bool, error) { return false, fmt.Errorf("check failed") },
		},
	}

	g, err := NewGraph(nodes)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err == nil {
		t.Fatal("expected error from staleness check")
	}
	if results[0].Status != StatusError {
		t.Errorf("expected status 'error', got %q", results[0].Status)
	}
}

func TestRunEmptyGraph(t *testing.T) {
	g, err := NewGraph(nil)
	if err != nil {
		t.Fatal(err)
	}

	ctx := &Context{Workers: 1}
	results, err := Run(g, ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}
