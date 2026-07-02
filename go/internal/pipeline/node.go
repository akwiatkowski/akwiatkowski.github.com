package pipeline

// Node represents a unit of work in the build pipeline.
type Node interface {
	Name() string
	Deps() []string
	IsStale(ctx *Context) (bool, error)
	Run(ctx *Context) error
}

// SimpleNode is a convenience implementation of Node using function fields.
type SimpleNode struct {
	NodeName string
	NodeDeps []string
	StaleFn  func(*Context) (bool, error)
	RunFn    func(*Context) error
}

func (n *SimpleNode) Name() string   { return n.NodeName }
func (n *SimpleNode) Deps() []string { return n.NodeDeps }

func (n *SimpleNode) IsStale(ctx *Context) (bool, error) {
	if n.StaleFn != nil {
		return n.StaleFn(ctx)
	}
	return true, nil // always stale by default
}

func (n *SimpleNode) Run(ctx *Context) error {
	if n.RunFn != nil {
		return n.RunFn(ctx)
	}
	return nil
}
