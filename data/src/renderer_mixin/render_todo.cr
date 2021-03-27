module RendererMixin::RenderTodo
  def render_todo_routes
    todos_all = @blog.data_manager.not_nil!.todo_routes.not_nil!

    # all
    todos = todos_all.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/", prechecked: TodosView::FILTER_CHECKED_STANDARD)
    write_output(view)

    # close - within 150 minutes of train
    todos = todos_all.select { |t| t.close? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/close", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # full_day - 150-270 (2.5-4.5h) minutes of train
    todos = todos_all.select { |t| t.full_day? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/full_day", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # external - >270 (4.5h) minutes of train
    todos = todos_all.select { |t| t.external? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/external", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # touring - longer than 140km
    todos = todos_all.select { |t| t.touring? }.sort { |a, b| a.distance <=> b.distance }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/touring", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "from"
    todos = todos_all.sort { |a, b| a.from <=> b.from }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/from", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # order by "transport_total_cost_minutes"
    todos = todos_all.sort { |a, b| a.transport_total_cost_minutes <=> b.transport_total_cost_minutes }
    view = TodosView.new(blog: @blog, todos: todos, url: "/todos/order_by/transport_cost", prechecked: TodosView::FILTER_CHECKED_ALL)
    write_output(view)

    # by major town near
    major_towns = @blog.data_manager.not_nil!.transport_pois.not_nil!.select(&.major)
    major_towns.each do |major_town|
      todos = todos_all.select { |todo_route|
        (todo_route.from_poi && todo_route.from_poi.not_nil!.closest_major_name == major_town.name) ||
          (todo_route.to_poi && todo_route.to_poi.not_nil!.closest_major_name == major_town.name)
      }
      url = "/todos/town/#{major_town.name.downcase.gsub(/\s/, "_")}"
      view = TodosView.new(blog: @blog, todos: todos, url: url, prechecked: TodosView::FILTER_CHECKED_ALL)
      write_output(view)
    end

    # notes from markdown
    view = MarkdownPageView.new(
      blog: @blog,
      url: "/todos/notes",
      file: "todo_notes",
      image_url: @blog.data_manager.not_nil!["todos.backgrounds"],
      title: @blog.data_manager.not_nil!["todos.title"],
      subtitle: @blog.data_manager.not_nil!["todos.subtitle"]
    )
    write_output(view)
  end
end
