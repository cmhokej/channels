window.ParticipantsView = class ParticipantsView extends Backbone.View
    el: '.user-list'

    initialize: ->

        _.bindAll @

        @collection = new UserList
        @collection.on 'add', @appendUser
        @collection.on 'remove', @clearUser
        @collection.on 'add remove', @changed
        @addUser window.the_user

    changed: ->
        @trigger "membership"

    appendUser: (user) ->
        user_view = new UserView model: user

        um = user_view.render()
        $('#' + @id).append um.el
        $('img', um.$el).tooltip()

    addUser: (user) ->
        if not @hasUser(user) and not user.isAnonymous()
            @collection.add user

    hasUser: (user) ->
        if @collection.get user.id then true else false

    removeUser: (user) ->
        if not user.isUser(window.the_user)
            @collection.remove user

    clearUser: (user) ->
        $('#' + @id + ' li:has(img[src="' + user.get("avatar") + '"])')
            .remove()

    usernameList: ->
        @collection.map (user) ->
            user.get "name"

    addTestData: ->
        _.each ['matt', 'maybe', 'mell', 'martha'], (n) =>
            @addUser new User
                name: n
                id: n + '1'
                avatar: 'https://securecdn.disqus.com/uploads/users/843/7354/avatar92.jpg?1330749766'


UserView = class UserView extends Backbone.View
    tagName: 'li'
    template: _.template $('#participant-template').html()

    initialize: ->
        _.bindAll @

    render: ->
        @$el.html @template @model.toJSON()
        @


class UserList extends Backbone.Collection

    model: User


window.ActiveThreadsView = class ActiveThreadsView extends Backbone.View
    el: '#thread-list'

    initialize: ->

        _.bindAll @

        @collection = new ThreadList
        @collection.on 'add', @appendThread
        @collection.on 'remove', @clearThread

    appendThread: (thread) ->
        thread_view = new ThreadView
            model: thread
            id: @id + thread.id

        um = thread_view.render()
        $('#' + @id).append um.el

    addThread: (thread) ->
        if not @hasThread thread
            @collection.add thread
        else
            t = @collection.get thread.id
            t.set('posts', thread.get "posts")

    hasThread: (thread) ->
        if @collection.get thread.id then true else false

    removethread: (thread) ->
        @collection.remove thread

    clearthread: (thread) ->
        $('li[data-thread="' + @id + '"]', el).remove()


class ThreadView extends Backbone.View
    tagName: 'li'
    className: 'thread'
    template: _.template $('#thread-template').html()

    initialize: ->
        _.bindAll @
        @model.on "change:posts", @updatePosts

    updatePosts: (p) ->
        $('.thread-count', this.$el).text @model.get("posts")

    render: ->
        @$el.html @template @model.toJSON()
        @


class ThreadList extends Backbone.Collection

    model: Thread


window.PostListView = class PostListView extends Backbone.View
    el: '.post-list'

    initialize: ->

        _.bindAll @

        @timeouts = {}
        @collection = new PostList
        @collection.on 'add', @appendPost
        @collection.on 'remove', @clearPost

    appendPost: (post) ->
        post_view = new PostView
            model: post
            id: post.eid()

        scrolled = @isAtBottom()
        @$el.append post_view.render().el
        if scrolled
            @scrollBottom()

    addPost: (post) ->
        @collection.add post

    scrollBottom: ->
        $('body, html').animate scrollTop: $(document).height(), 0

    isAtBottom: ->
        $(window).scrollTop() + $(window).height() == $(document).height()

    error: (post) ->
        @_clearTimeout post
        that = @
        $('#' + post.eid() + ' .post-resend').show().click () ->
            $('button', this).button 'loading'
            $.ajax
                url: $('form').attr 'action'
                type: 'POST'
                data: post.toJSON()
                error: (jqxr, status, error) =>
                    $('button', this).button 'reset'
                success: (data, status, jqxhr) =>
                    serverPost = new Post data.post
                    that.commit post, serverPost
                    $('button', this).hide()

    _clearTimeout: (post) ->
        clearTimeout @timeouts[post.cid]
        delete @timeouts[post.cid]

    commit: (post, serverPost) ->
        scrolled = @isAtBottom()
        post.set "message", serverPost.get "message"
        if scrolled
            @scrollBottom()
        post.id = serverPost.id

        @_clearTimeout post

    addTentatively: (post) ->
        @addPost post
        @timeouts[post.cid] = setTimeout () =>
            @error post
        , 10 * 1000

    removePost: (post) ->
        @collection.remove post

    clearPost: (post) ->
        $('#' + post.eid()).remove()

    hasPost: (post) ->
        if @collection.get post.id then true else false


class PostView extends Backbone.View
    tagName: 'li'
    className: 'post'
    template: _.template $('#post-template').html()

    initialize: ->
        _.bindAll @
        @model.on 'change:message', @updateMessage

    updateMessage: (post) ->
        $('#' + @model.eid() + ' .post-message')
            .html @model.get("message")

    render: () ->
        obj = @model.toJSON()
        if @model.isNew()
            obj.message = @model.formattedMsg()
        @$el.html @template obj

        if @model.get("class") == "system"
            @$el.addClass 'system-message'
        else if @model.isAuthor window.the_user
            @$el.addClass('author')
        else if @model.mentions window.the_user
            if ding? and ding.play?
                ding.play()
            @$el.addClass('highlight')
        @


class PostList extends Backbone.Collection

    model: Post
