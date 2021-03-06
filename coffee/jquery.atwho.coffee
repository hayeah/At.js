(($) ->
    Mirror = ($origin) ->
        @.init $origin
        this

    Mirror:: =
        $mirror: null
        css: ["overflowY", "height", "width", "paddingTop", "paddingLeft", "paddingRight", "paddingBottom", "marginTop", "marginLeft", "marginRight", "marginBottom",'fontFamily', 'borderStyle', 'borderWidth','wordWrap', 'fontSize', 'lineHeight', 'overflowX']
        init: ($origin) ->
            $mirror = $('<div></div>')
            css =
                opacity: 0
                position: 'absolute'
                left: 0
                top:0
                zIndex: -20000
                'white-space': 'pre-wrap'
            $.each @.css, (i,p) ->
                css[p] = $origin.css p
            $mirror.css(css)
            $('body').append $mirror
            @.$mirror = $mirror
        setContent: (html) ->
            @.$mirror.html(html)
        getFlagRect: () ->
            $flag = @.$mirror.find "span#flag"
            pos = $flag.position()
            {left:pos.left, top:pos.top, bottom:$flag.height() + pos.top}
        height: () ->
            @.$mirror.height()

    At = (inputor) ->
        $inputor = @.$inputor = $(inputor)
        @options = {}
        @keyword =
            text:""
            start:0
            stop:0
        @_cache = {}
        @pos = 0
        @flags = {}
        @theflag = null
        @search_word = {}

        @view = AtView
        @mirror = new Mirror $inputor

        $inputor
            .on "keyup.inputor", (e) =>
                stop = e.keyCode is 40 or e.keyCode is 38
                lookup = not (stop and @.view.isShowing())
                @.lookup() if lookup
            .on "mouseup.inputor",(e) =>
                @.lookup()
        @.init()
        log "At.new", $inputor[0]
        return this

    At:: =
        constructor: At

        init: ->
            @.$inputor
                .on 'keydown.inputor', (e) =>
                    @.onkeydown(e)
                .on 'scroll.inputor', (e) =>
                    @.view.hide()
                .on 'blur.inputor', (e) =>
                    callback = => @.view.hide()
                    @.view.timeout_id = setTimeout callback,150
            log "At.init", @.$inputor[0]

        reg: (flag, options) ->
            opt = {}
            if $.isFunction options
                opt['callback'] = options
            else
                opt = options
            @.options[flag] = $.extend {}, $.fn.atWho.default, opt
            log "At.reg", @.$inputor[0],flag, options

        searchWord: ->
            search_word = @.search_word[@.theflag]
            return search_word if search_word
            match = /data-value=['?]\$\{(\w+)\}/g.exec(this.getOpt('tpl'))
            return @.search_word[@.theflag] =  if !_isNil(match) then match[1] else null

        getOpt: (key) ->
            try
                return @.options[@.theflag][key]
            catch error
                return null

        rect: ->
            $inputor = @.$inputor
            if document.selection # for IE full
                Sel = document.selection.createRange()
                x = Sel.boundingLeft + $inputor.scrollLeft()
                y = Sel.boundingTop + $(window).scrollTop() + $inputor.scrollTop()
                bottom = y + Sel.boundingHeight
                return {top:y, left:x, bottom:bottom}

            mirror = @.mirror

            format = (value) ->
                value.replace(/</g, '&lt')
                    .replace(/>/g, '&gt')
                    .replace(/`/g,'&#96')
                    .replace(/"/g,'&quot')
                    .replace(/\r\n|\r|\n/g,"<br />")

            ### 克隆完inputor后将原来的文本内容根据
              @的位置进行分块,以获取@块在inputor(输入框)里的position
            ###
            text = $inputor.val()
            start_range = text.slice(0,this.pos - 1)
            end_range = text.slice(this.pos + 1)
            html = "<span>"+format(start_range)+"</span>"
            html += "<span id='flag'>@</span>"
            html += "<span>"+format(end_range)+"</span>"
            mirror.setContent(html)

            ###
              将inputor的 offset(相对于document)
              和@在inputor里的position相加
              就得到了@相对于document的offset.
              当然,还要加上行高和滚动条的偏移量.
            ###
            offset = $inputor.offset()
            at_rect = mirror.getFlagRect()

            ###
            FIXME: -$(window).scrollTop() get "wrong" offset.
             but is good for $inputor.scrollTop()
             jquey 1. + 07.1 fixed the scrollTop problem!?
             ###
            x = offset.left + at_rect.left - $inputor.scrollLeft()
            y = offset.top - $inputor.scrollTop()
            bottom = y + at_rect.bottom
            y += at_rect.top

            return {top:y,left:x,bottom:bottom}

        cache: (value) ->
            key = @.keyword.text
            return null if not @.getOpt("cache") or not key
            return @._cache[key] or= value

        getKeyname: ->
            $inputor = @.$inputor
            text = $inputor.val()

            ##获得inputor中插入符的position.
            caret_pos = $inputor.caretPos()

            ### 向在插入符前的的文本进行正则匹配
             * 考虑会有多个 @ 的存在, 匹配离插入符最近的一个###
            subtext = text.slice(0,caret_pos)

            matched = null
            $.each this.options, (flag) =>
                regexp = new RegExp flag+'([A-Za-z0-9_\+\-]*)$|'+flag+'([^\\x00-\\xff]*)$','gi'
                match = regexp.exec subtext
                if not _isNil(match)
                    matched = if match[1] is 'undefined' then match[2] else match[1]
                    @.theflag = flag
                    return no

            if typeof matched is 'string' and matched.length <= 20
                start = caret_pos - matched.length
                end = start + matched.length
                @.pos = start
                key = {'text':matched, 'start':start, 'end':end}
            else
                @.view.hide()

            log "At.getKeyname", key
            @.keyword = key

        replaceStr: (str) ->
            #$inputor.replaceStr(str,start,end)
            $inputor = @.$inputor
            key = @.keyword
            source = $inputor.val()
            start_str = source.slice 0, key.start
            text = start_str + str + source.slice key.end

            $inputor.val text
            $inputor.caretPos start_str.length + str.length
            $inputor.change()

        onkeydown: (e) ->
            view = @.view
            return if not view.isShowing()
            switch e.keyCode
                # UP
                when 38
                    e.preventDefault()
                    view.prev()
                # DOWN
                when 40
                    e.preventDefault()
                    view.next()
                # TAB or ENTER
                when 9, 13
                    return if not view.isShowing()
                    e.preventDefault()
                    view.choose()
                else
                    $.noop()
            e.stopPropagation()

        loadView: (datas) ->
            log "At.loadView", this, datas
            this.view.load this, datas

        lookup: ->
            key = this.getKeyname()
            return no if not key
            log "At.lookup.key", key

            if not _isNil(datas = @.cache())
                @.loadView datas
            else if not _isNil(datas = @.lookupWithData key)
                @.loadView datas
            else if $.isFunction(callback = @.getOpt 'callback')
                callback key.text, $.proxy(@.loadView,@)
            else
                @.view.hide()
            $.noop()

        lookupWithData: (key) ->
            data = @.getOpt "data"
            if $.isArray(data) and data.length != 0
                items = $.map data, (item,i) =>
                    try
                        name = if $.isPlainObject item then item[@.searchWord()] else item
                        regexp = new RegExp(key.text.replace("+","\\+"),'i')
                        match = name.match(regexp)
                    catch e
                        return null

                    return if match then item else null
            items

    AtView =
        timeout_id: null
        id: '#at-view'
        holder: null
        _jqo: null
        jqo: ->
            jqo = @._jqo
            jqo = if _isNil jqo then (@._jqo = $(@.id)) else jqo

        init: ->
            return if not _isNil @.jqo()
            tpl = "<div id='"+this.id.slice(1)+"' class='at-view'><ul id='"+this.id.slice(1)+"-ul'></ul></div>"
            $("body").append(tpl)

            $menu = @.jqo().find('ul')
            $menu.on 'mouseenter.view','li', (e) ->
                    $menu.find('.cur').removeClass 'cur'
                    $(e.currentTarget).addClass 'cur'
                .on 'click', (e) =>
                    e.stopPropagation()
                    e.preventDefault()
                    @.choose()


        isShowing: () ->
            @.jqo().is(":visible")

        choose: () ->
            $li = @.jqo().find ".cur"
            str = if _isNil($li) then @.holder.keyword.text+" " else $li.attr("data-value") + " "
            @.holder.replaceStr(str)
            @.hide()
        rePosition: () ->
            rect = @.holder.rect()
            if rect.bottom + @.jqo().height() > $(window).height()
                rect.bottom = rect.top - @.jqo().height()
            log "AtView.rePosition",{left:rect.left, top:rect.bottom}
            @.jqo().offset {left:rect.left, top:rect.bottom}

        next: (e) ->
            cur = @.jqo().find('.cur').removeClass('cur')
            next = cur.next()
            next = $(@.jqo().find('li')[0]) if not cur.length
            next.addClass 'cur'

        prev: (e) ->
            cur = @.jqo().find('.cur').removeClass('cur')
            prev = cur.prev()
            prev = @.jqo().find('li').last() if not prev.length
            prev.addClass('cur')

        show: (e) ->
            @.jqo().show() if not @.isShowing()
            @.rePosition()

        hide: (e) ->
            @.jqo().hide() if @.isShowing()

        clear: (clear_all) ->
            @._cache = {} if clear_all is yes
            @.jqo().find('ul').empty()

        load: (holder, list) ->
            return no if not $.isArray(list)
            @.holder = holder
            holder.cache(list)
            @.clear()

            tpl = holder.getOpt('tpl')
            list = _unique(list, holder.searchWord())

            $ul = @.jqo().find('ul')
            $.each list.splice(0, holder.getOpt('limit')), (i, item) ->
                if not $.isPlainObject item
                    item = {id:i, name:item}
                    tpl = _DEFAULT_TPL
                $ul.append _evalTpl tpl, item
            @.show()
            $ul.find("li:eq(0)").addClass "cur"

    _evalTpl = (tpl, map) ->
        try
            el = tpl.replace /\$\{([^\}]*)\}/g, (tag,key,pos) ->
                map[key]
        catch error
            ""
    ###
      maybe we can use $._unique.
      But i don't know it will delete li element frequently or not.
      I think we should not change DOM element frequently.
      more, It seems batter not to call evalTpl function too much times.
    ###
    _unique = (list,keyword) ->
        record = []
        $.map list, (v, id) ->
            value = if $.isPlainObject(v) then v[keyword] else v
            if $.inArray(value,record) < 0
                record.push value
                return v

    _isNil = (target) ->
        not target \
        or ($.isPlainObject(target) and $.isEmptyObject(target)) \
        or ($.isArray(target) and target.length is 0) \
        or (target instanceof $ and target.length is 0) \
        or target is undefined

    _DEFAULT_TPL = "<li id='${id}' data-value='${name}'>${name}</li>"
    
    log = () ->
        #console.log(arguments)

    $.fn.atWho = (flag, options) ->
        AtView.init()
        @.filter('textarea, input').each () ->
            $this = $(this)
            data = $this.data "AtWho"

            $this.data 'AtWho', (data = new At(this)) if not data
            data.reg flag, options

    $.fn.atWho.default =
        data: []
        callback: null
        cache: yes
        limit: 5
        tpl: _DEFAULT_TPL

)(window.jQuery)
