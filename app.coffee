# Collection to keep the todos
Todos = new Meteor.Collection("todos")

if Meteor.is_server

  Todos.allow
    'insert': (uid,doc)->
      true
    'update': (uid,doc)->
      true
    'remove': -> true

# JS code for the client (browser)
if Meteor.is_client
  
  # Session var to keep current filter type ("all", "active", "completed")
  Session.set "filter", "all"
  
  # Session var to keep todo which is currently in editing mode, if any
  Session.set "editing_todo", null
  
  # Set up filter types and their mongo db selectors
  filter_selections =
    all: {}
    active:
      completed: false

    completed:
      completed: true

  
  # Get selector types as array
  filters = _.keys(filter_selections)
  
  # Bind route handlers to filter types
  routes = {}
  _.each filters, (filter) ->
    routes["/" + filter] = ->
      Session.set "filter", filter

  
  # Initialize router with routes
  router = Router(routes)
  router.init()
  
  #///////////////////////////////////////////////////////////////////////
  # The following two functions are taken from the official Meteor
  # "Todos" example
  # The original code can be viewed at: https://github.com/meteor/meteor
  #///////////////////////////////////////////////////////////////////////
  
  # Returns an event_map key for attaching "ok/cancel" events to
  # a text input (given by selector)
  okcancel_events = (selector) ->
    "keyup " + selector + ", keydown " + selector + ", focusout " + selector

  
  # Creates an event handler for interpreting "escape", "return", and "blur"
  # on a text field and calling "ok" or "cancel" callbacks.
  make_okcancel_handler = (options) ->
    ok = options.ok or ->

    cancel = options.cancel or ->

    (evt) ->
      if evt.type is "keydown" and evt.which is 27
        
        # escape = cancel
        cancel.call this, evt
      else if evt.type is "keyup" and evt.which is 13 or evt.type is "focusout"
        
        # blur/return/enter = ok/submit if non-empty
        value = String(evt.target.value or "")
        if value
          ok.call this, value, evt
        else
          cancel.call this, evt

  
  #//
  # Logic for the 'todoapp' partial which represents the whole app
  #//
  
  # Helper to get the number of todos
  Template.todoapp.todos = ->
    Todos.find().count()

  Template.todoapp.events = {}
  
  # Register key events for adding new todo
  Template.todoapp.events[okcancel_events("#new-todo")] = make_okcancel_handler(ok: (title, evt) ->
    Todos.insert
      title: $.trim(title)
      completed: false
      created_at: new Date().getTime()

    evt.target.value = ""
  )
  
  #//
  # Logic for the 'main' partial which wraps the actual todo list
  #//
  
  _.extend Template.main,
    # Get the todos considering the current filter type
    todos: ->
      Todos.find filter_selections[Session.get("filter")],
        sort:
          created_at: 1

    todos_not_completed: ->
      Todos.find(completed: false).count()
 
    # Register click event for toggling complete/not complete button
    events: "click input#toggle-all": (evt) ->
      completed = true
      completed = false  unless Todos.find(completed: false).count()
      Todos.find({}).forEach (todo) ->
        Todos.update
          _id: todo._id
        ,
          $set:
            completed: completed
    
  #//
  # Logic for the 'todo' partial representing a todo
  #//
  
  _.extend Template.todo,
    todo_completed: -> @completed
  
    todo_editing: ->
      Session.equals "editing_todo", @_id
  
    events:
      "click input.toggle": ->
        Todos.update @_id,
          $set:
            completed: not @completed


      "dblclick label": ->
        Session.set "editing_todo", @_id

      "click button.destroy": ->
        Todos.remove @_id

  # Register key events for updating title of an existing todo
  Template.todo.events[okcancel_events("li.editing input.edit")] = make_okcancel_handler(
    ok: (value) ->
      Session.set "editing_todo", null
      Todos.update @_id,
        $set:
          title: $.trim(value)


    cancel: ->
      Session.set "editing_todo", null
      Todos.remove @_id
  )
  
  #//
  # Logic for the 'footer' partial
  #//

  _.extend Template.footer,
    todos_completed: -> Todos.find(completed: true).count()
 
    todos_not_completed: ->
      Todos.find(completed: false).count()
  
    todos_one_not_completed: ->
      Todos.find(completed: false).count() is 1
  
    filters: filters

    filter_selected: (type) ->
      Session.equals "filter", type
  
    events:
      "click button#clear-completed": ->
        Todos.remove completed: true
