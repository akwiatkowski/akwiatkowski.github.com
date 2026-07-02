package pipeline

import (
	"errors"
	"testing"
)

func TestPipelineEmpty(t *testing.T) {
	pipe := NewPipeline()
	if err := pipe.Run(&Context{}); err != nil {
		t.Fatal(err)
	}
}

func TestPipelineExecutionOrder(t *testing.T) {
	pipe := NewPipeline()
	var order []string

	// Register out of dependency order to test sorting
	pipe.Add("c", []string{"a", "b"}, func(_ *Context) error {
		order = append(order, "c")
		return nil
	})
	pipe.Add("a", nil, func(_ *Context) error {
		order = append(order, "a")
		return nil
	})
	pipe.Add("b", []string{"a"}, func(_ *Context) error {
		order = append(order, "b")
		return nil
	})

	if err := pipe.Run(&Context{}); err != nil {
		t.Fatal(err)
	}

	// a must come before b and c; b must come before c
	aIdx := indexOf(order, "a")
	bIdx := indexOf(order, "b")
	cIdx := indexOf(order, "c")

	if aIdx > bIdx {
		t.Errorf("a ran after b: %v", order)
	}
	if aIdx > cIdx {
		t.Errorf("a ran after c: %v", order)
	}
	if bIdx > cIdx {
		t.Errorf("b ran after c: %v", order)
	}
}

func TestPipelineIndependentNodesPreserveRegistrationOrder(t *testing.T) {
	pipe := NewPipeline()
	var order []string

	pipe.Add("first", nil, func(_ *Context) error { order = append(order, "first"); return nil })
	pipe.Add("second", nil, func(_ *Context) error { order = append(order, "second"); return nil })
	pipe.Add("third", nil, func(_ *Context) error { order = append(order, "third"); return nil })

	if err := pipe.Run(&Context{}); err != nil {
		t.Fatal(err)
	}

	if len(order) != 3 || order[0] != "first" || order[1] != "second" || order[2] != "third" {
		t.Errorf("expected registration order, got %v", order)
	}
}

func TestPipelineCycleDetection(t *testing.T) {
	pipe := NewPipeline()
	pipe.Add("a", []string{"b"}, func(_ *Context) error { return nil })
	pipe.Add("b", []string{"a"}, func(_ *Context) error { return nil })

	err := pipe.Run(&Context{})
	if err == nil {
		t.Fatal("expected cycle error")
	}
}

func TestPipelineUnknownDep(t *testing.T) {
	pipe := NewPipeline()
	pipe.Add("a", []string{"nonexistent"}, func(_ *Context) error { return nil })

	err := pipe.Run(&Context{})
	if err == nil {
		t.Fatal("expected unknown dep error")
	}
}

func TestPipelineStopsOnError(t *testing.T) {
	pipe := NewPipeline()
	var ran []string

	pipe.Add("a", nil, func(_ *Context) error {
		ran = append(ran, "a")
		return errors.New("boom")
	})
	pipe.Add("b", []string{"a"}, func(_ *Context) error {
		ran = append(ran, "b")
		return nil
	})

	err := pipe.Run(&Context{})
	if err == nil {
		t.Fatal("expected error")
	}
	if len(ran) != 1 || ran[0] != "a" {
		t.Errorf("expected only a to run, got %v", ran)
	}
}

func TestPipelineErrorContainsNodeName(t *testing.T) {
	pipe := NewPipeline()
	pipe.Add("loadData", nil, func(_ *Context) error {
		return errors.New("file not found")
	})

	err := pipe.Run(&Context{})
	if err == nil {
		t.Fatal("expected error")
	}
	if err.Error() != "loadData: file not found" {
		t.Errorf("error = %q, want 'loadData: file not found'", err.Error())
	}
}

func TestPipelineDuplicatePanics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic for duplicate name")
		}
	}()
	pipe := NewPipeline()
	pipe.Add("a", nil, func(_ *Context) error { return nil })
	pipe.Add("a", nil, func(_ *Context) error { return nil })
}

func TestPipelineLen(t *testing.T) {
	pipe := NewPipeline()
	if pipe.Len() != 0 {
		t.Errorf("empty pipeline len = %d", pipe.Len())
	}
	pipe.Add("a", nil, func(_ *Context) error { return nil })
	pipe.Add("b", nil, func(_ *Context) error { return nil })
	if pipe.Len() != 2 {
		t.Errorf("pipeline len = %d, want 2", pipe.Len())
	}
}

func TestPipelineDataFlowViaContext(t *testing.T) {
	pipe := NewPipeline()

	pipe.Add("produce", nil, func(ctx *Context) error {
		ctx.StoreResult("value", 42)
		return nil
	})
	pipe.Add("consume", []string{"produce"}, func(ctx *Context) error {
		val, ok := ctx.Result("value")
		if !ok {
			return errors.New("missing value")
		}
		if val.(int) != 42 {
			return errors.New("wrong value")
		}
		return nil
	})

	if err := pipe.Run(&Context{}); err != nil {
		t.Fatal(err)
	}
}

func TestPipelineDiamondDependency(t *testing.T) {
	// A → B, A → C, B → D, C → D (diamond shape)
	pipe := NewPipeline()
	var order []string

	pipe.Add("A", nil, func(_ *Context) error { order = append(order, "A"); return nil })
	pipe.Add("B", []string{"A"}, func(_ *Context) error { order = append(order, "B"); return nil })
	pipe.Add("C", []string{"A"}, func(_ *Context) error { order = append(order, "C"); return nil })
	pipe.Add("D", []string{"B", "C"}, func(_ *Context) error { order = append(order, "D"); return nil })

	if err := pipe.Run(&Context{}); err != nil {
		t.Fatal(err)
	}

	aIdx := indexOf(order, "A")
	dIdx := indexOf(order, "D")
	if aIdx > dIdx {
		t.Errorf("A ran after D: %v", order)
	}
	if indexOf(order, "B") > dIdx || indexOf(order, "C") > dIdx {
		t.Errorf("B or C ran after D: %v", order)
	}
}

func indexOf(slice []string, val string) int {
	for i, s := range slice {
		if s == val {
			return i
		}
	}
	return -1
}
