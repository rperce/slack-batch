global_files = []
params = decodeURIComponent(document.URL).extract() || {}

window.onload = () ->
    container = $('#selectrows')
    container.on('click', selectrowsEventHandler)
    container.on('input paste', 'input', doValidityCheck)
    $('#api').val(params.token)
    filtered = _.object(
        _(params).pairs().filter((pair) ->
            !_.contains(['token', 'team'], pair[0])
        ))
    i = 1
    _.each(filtered, (v, k) ->
        container.append generate_where_row(i, k, v.substr(0,1), v.substr(1))
        i += 1
    )
    container.append generate_where_row(i)
    generate_request(params, (files) ->
        augment_and_filter_request(files, (files) ->
            files = filterPost(files)
            _(files).forEach((file) ->
                $('#data').append build_file_view(file)
                global_files.push file
            )
            $('#loading_icon').remove()
            $('#data').prepend delete_button()
        )
    )
    $('#submit_button').on('click', redir_submit_link)

doValidityCheck = (event) ->
    id    = getID($(event.target))
    left  = $("#where_left_#{id}")
    right = $("#where_right_#{id}")
    mid   = $("#where_oper_#{id}")
    sel   = (m, k) -> if m == k then 'selected' else ''
    style = (input, border, midHTML, valid_text) ->
        field = $(input.parent())
        field.css('border-color', border)
        field.children('label').css('background-color', border)
        $("#valid_text_#{id} span").html(valid_text) if valid_text
        mid.html(midHTML) if midHTML

    if left.val().length == 0 or !_(_(fields).keys()).contains(left.val())
        style(left, (if left.val().length > 0 then 'red' else '#aaa'),
            _.map(operator_names, (v, k) ->
               "<option value='#{k}' #{sel(mid.val(), k)}>#{v}</option>"
            ).join("\n"),
                "Type a valid field in the left box!"
        )
    else
        html = _.map(hash_filter(operator_names, (v, k) ->
            k == '' || _.contains(fields[left.val()].ops, k)
        ), (v, k) ->
            "<option value='#{k}' #{sel(mid.val(), k)}>#{v}</option>"
        ).join("\n")
        style(left, '#aaa', html, fields[left.val()].valid_text)
        rightcolor = '#aaa'
        if not fields[left.val()].valid(right.val())
            rightcolor = 'red'
        style(right, rightcolor)

delete_button = () ->
    out = $("<span class='field' id='delete_button'><input type='button' value='Delete All'></input></span>")
    out.on('click', (event) ->
        button = $(out.children()[0])
        if button.val() == 'Delete All'
            button.val('Click again within three seconds to confirm')
            setTimeout((() -> button.val('Delete All')), 3000)
            return
        else
            _(global_files).forEach((file, index) ->
                do_slack_request('files.delete', {file: file.id})
                $("#fieldview_#{index}").remove()
            )
    )
    return out

redir_submit_link = () ->
    params = {}
    params.token = $('#api').val()
    for child in $('#selectrows').children()
        id = getID($(child))
        arg = $( "#where_left_#{id}" ).val()
        if arg
            params[arg] = $( "#where_oper_#{id}" ).val() + $( "#where_right_#{id}" ).val()
    console.log(params)
    url = window.location.href
    url = url.split('?')[0] if url.indexOf('?') > 0
    url += '?' + _.map(params, (v, k) -> return "#{k}=#{v}" ).join('&')
    window.location.href = url

getID = (target) ->
    +target.attr('id').split('_').slice(-1)

selectrowsEventHandler = (event) ->
    classes = event.target.classList
    rows = $('#selectrows')
    if _.contains(classes, 'fa-minus')
        $( '#fieldrow_' + getID($(event.target)) ).remove()
        if rows.children().length == 0
            rows.append(generate_where_row(1))
    else if _.contains(classes, 'fa-plus')
        rows.append(generate_where_row( getID($('#selectrows').children().last()) + 1 ))

generate_where_row = (id, l, m, r) ->
    l ||= ''
    m ||= ''
    r ||= ''
    sel = (m, k) -> if m == k then 'selected' else ''
    return  """
            <div class='fieldrow' id='fieldrow_#{id}'>
            <span>
                <div class='field' class='param_input'>
                    <input type='text' id='where_left_#{id}' placeholder='Field' value='#{l}' />
                    <span class="fa fa-question-circle">
                        <span class='valid-left'>#{_(fields).keys().join(', ')}</span>
                    </span>
                    <label for='where_left_#{id}'>Field</label>
                </div>
            </span>
            <span>
                <div class='field'>
                    <select required id='where_oper_#{id}' selected='#{m}'>
                    #{_.map(operator_names, (v, k) ->
                        "<option value='#{k}' #{sel(m, k)}>#{v}</option>").join("\n")}
                    </select>
                    <label>Operator</label>
                </div>
            </span>
            <span>
                <div class='field'>
                    <input type='text' id='where_right_#{id}' placeholder='Comparison' value='#{r}' />
                    <span class="fa fa-question-circle valid-right" id='valid_text_#{id}'>
                        <span class='valid-right'>Type a valid field in the left box!</span>
                    </span>
                    <label for='where_right_${id}'>Comparison</label>
                </div>
            </span>
            <span class="fa fa-minus" id='where_remove_#{id}'></span>
            <span class="fa fa-plus" id='where_add_#{id}'></span>
            </div>
            """

_op = (s) -> if s then s.substr(0,1) else ''
_val = (s) -> if s then s.substr(1) else ''
all_types = ['posts','snippets','images','gdocs','zips','pdfs']
generate_request = (params, callback) ->
    username = _val(params.user) if _op(params.user) == '_'
    submit = {}
    submit.token = params.token
    ids = []
    if username
        do_slack_request('users.list', submit, 'members', (members) ->
            ids = _(members).filter((user) ->
                user.name == username
            ).map((user) ->
                user.id
            )
            if ids.length == 0
                callback({ok: false, error: 'user_not_found'})
                return
            return do_request(params, callback, submit, ids)
        )
    else
        return do_request(params, callback, submit, ids)

do_request = (params, callback, submit, users) ->
    users.push(undefined) if users.length == 0
    for user in users
        submit.ts_from = _val(params.time) if _.contains(['>', '_'], _op(params.time))
        submit.ts_to = _val(params.time) if _.contains(['<', '_'], _op(params.time))
        submit.user = user if user
        types = _val(params.type) if _.contains(['_','!'], _op(params.type))
        if types
            types = if types.indexOf(',') > 0 then types.split(',') else [types]
            if _op(params.type) == '!'
                types = _.difference(all_types, types)
            submit.types = _(types).map((str) -> str.trim()).join(',')
        submit.count = 100
        submit.count = _val(params.limit) if '_' == _op(params.limit)
        do_slack_request('files.list', submit, 'files', callback)

toBytes = (size) ->
    c = size.substr(-1)
    f = size.substr(0, size.length-1)
    if c == 'K'
        f * 1000
    else if c == 'M'
        f * 1000 * 1000
    else if c == 'G'
        f * 1000 * 1000 * 1000
    else
        size

toBool = (s) ->
    true if _(['true', 'yes']).contains(s)
    false

cmp = (a, op, b) ->
    if not b # op is actually the param value in this case
        b = _val(op)
        op = _op(op)

    if op == '_'
        a == b
    else if op == '!'
        a != b
    else if op == '>'
        +a > +b
    else if op == '<'
        +a < +b
    else if op == '~'
        new RegExp(b).test(a)
    else
        false

filterPre = (files) ->
    return _(files).filter((file) ->
        keep = yes
        if params.size
            keep = no unless cmp(file.size, _op(params.size), toBytes(_val(params.size)))

        if params.name
            keep = no unless cmp(file.name, params.name)

        if params.title
            keep = no unless cmp(file.title, params.title)

        if params.is_public
            keep = no unless cmp(file.is_public, _op(params.is_public), toBool(params.is_public))

        keep
    )

filterPost = (files) ->
    return _(files).filter((file) ->
        keep = yes
        if params.shared_in
            a  = file.shared_in
            op = _op(params.shared_in)
            b  = _val(params.shared_in)
            b = b.substr(1) if b.substr(0,1) == '#'
            console.log("a: #{a}")
            console.log("b: #{b}")
            if op == '~'
                keep = no unless _.any(a, (chan) -> new RegExp(b).test(chan))
            else if op == '_'
                keep = no unless _.any(a, (chan) -> chan == b)
            else if op == '!'
                keep = no unless _.every(a, (chan) -> chan != b)
        keep
    )

augment = (files, decode_ids, callback) ->
    _(files).forEach((file, index) ->
        file.user_name = decode_ids[file.user].user_name
        file.shared_in ||= []
        _(file.groups).forEach((group) ->
            file.shared_in.push decode_ids[group].group_name
        )
        _(file.channels).forEach((channel) ->
            file.shared_in.push decode_ids[channel].channel_name
        )
    )
    callback(files)

augment_and_filter_request = (files, callback) ->
    files = filterPre(files)
    count = 0

    decode_ids = {}
    _(files).forEach((file, index) ->
        decode_ids[file.user] = {
            want: 'user'
            pass: {user: file.user}
            func: (user) ->
                decode_ids[file.user].user_name = user.name
                count += 1
                augment(files, decode_ids, callback) if (count == limit)
        } unless decode_ids[file.user]
        _(file.groups).forEach((group) ->
            decode_ids[group] = {
                want: 'group'
                pass: {channel: group}
                func: (gobj) ->
                    decode_ids[group].group_name = gobj.name
                    count += 1
                    augment(files, decode_ids, callback) if (count == limit)
            } unless decode_ids[group]
        )
        _(file.channels).forEach((channel) ->
            decode_ids[channel] = {
                want: 'channel'
                pass: {channel: channel}
                func: (cobj) ->
                    decode_ids[channel].channel_name = "##{cobj.name}"
                    count += 1
                    augment(files, decode_ids, callback) if (count == limit)
            } unless decode_ids[channel]
        )
    )

    limit = _(decode_ids).keys().length
    _(decode_ids).forEach((obj, k) ->
        do_slack_request("#{obj.want}s.info", obj.pass, obj.want, obj.func)
    )

build_file_view = (file, index) ->
    file.shared_in ||= []
    $('#data').append(
        """
        <div class='fileview' id='fileview_#{index}'>
            <a href="#{file.permalink}">
                <img src=#{file.thumb_64} />
            </a>
            <div class='fv-metadata'>
                <span class='fv-img-title'>#{file.title} (#{file.name})</span>
                <span class='fv-user'>(#{file.user_name}) | #{file.size}B</span>
                <span class='fv-datetime'>#{new Date(1000*file.timestamp)}</span>
            </div>
            <div class='fv-spacer'></div>
            <div class='fv-metadata'>
                <span class='fv-shared-in'>#{file.shared_in.join(', ')}</span>
            </div>
        </div>
        """
    )

die = (error) ->
    console.log(error)
    $('#data').html("<div class='error'>#{error}</div>")

do_slack_request = (method, pass, want, callback) ->
    #console.log("pass:\n#{_(pass).map((v,k)->"  :: #{k}: #{v}").join("\n")}")
    pass.token = params.token
    $.post(
        "https://slack.com/api/#{method}", pass
    ).done( (data) ->
        if data.ok
            callback(data[want]) if callback
        else
            die "Slack API Error: #{data.error}"
    ).fail( (err) ->
        console.log("Slack API Error: #{err}");
        die "POST Error! See Javascript Console for details."
    )

operator_names = {
        '' : 'Operator',
        '_': 'is',
        '!': 'is not',
        '<': '&lt',
        '>': '&gt',
        '~': 'matches'
}

op_bool     = ['_', '!']
op_cmp      = ['<', '>']
op_nocmp    = _.union(op_bool, ['~'])
op_no_regex = _.union(op_bool, op_cmp)
op_all      = _.union(op_nocmp, op_cmp)
generic_valid_text = "Any text or, with 'matches', a JavaScript regular expression (leave out the slashes on the ends)."
fields = {
    'user': {
        'use': 'query',
        'ops': op_nocmp,
        'valid': (user) -> /^[a-z0-9][a-z0-9._-]*$/.test(user)
        'valid_text': "A letter or number followed by letters, numbers, periods, hypens, or underscores."
    },
    'time': {
        'use': 'query',
        'ops': op_all,
        'valid': (time) -> !isNaN(new Date(time).getTime())
        'valid_text': "Anything that works with Javascript's new Date(). The format '#{new Date()}' is guaranteed to work."
    },
    'type': {
        'use': 'query',
        'ops': op_nocmp,
        'valid': (types) ->
            _(types.split(',')).every((type) ->
                _(['posts','snippets','images','gdocs','zips','pdfs']).contains(type.trim())
            )
        'valid_text': "One of 'posts', 'snippets', 'images', 'gdocs', 'zips', or 'pdfs'; multiple types may be separated by commas."
    },
    'limit': {
        'use': 'query',
        'ops': ['_']
        'valid': (limit) -> /^[0-9]*$/.test(limit)
        'valid_text': "A number indicating how many files to show"
    },
    'name': {
        'use': 'filter',
        'ops': op_nocmp,
        'valid': -> yes
        'valid_text': generic_valid_text
    },
    'title': {
        'use': 'filter',
        'ops': op_nocmp,
        'valid': -> yes
        'valid_text': generic_valid_text
    },
    'is_public': {
        'use': 'filter',
        'ops': op_bool,
        'valid': (pub) -> _(['true','false','yes','no']).contains(pub)
        'valid_text': "One of 'true', 'yes', 'false', or 'no'"
    },
    'shared_in': {
        'use': 'filter',
        'ops': op_nocmp,
        'valid': -> yes
        'valid_text': generic_valid_text
    },
    'size': {
        'use': 'filter',
        'ops': op_no_regex,
        'valid': (size) -> /^[0-9]*[KMG]?$/.test(size)
        'valid_text': "A number representing the size in bytes of the file. May end in 'K', 'M', or 'G'"
    }
}

hash_filter = (hash, test_function) ->
    keys = Object.keys hash

    filtered = {}
    for key in keys
        filtered[key] = hash[key] if test_function(hash[key], key)
    filtered
