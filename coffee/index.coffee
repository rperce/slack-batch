fields = ['user', 'time', 'type']
window.onload = () ->
    container = document.getElementById('selectrows')
    container.innerHTML = generate_where_row(1)
    container.addEventListener('click', selectrowsEventHandler, false)

getID = (target) ->
    +target.id.split('_').slice(-1)

selectrowsEventHandler = (event) ->
    classes = event.target.classList
    rows = document.getElementById('selectrows')
    if _.contains(classes, 'fa-minus')
        rows.removeChild(document.getElementById( 'fieldrow_' + getID(event.target) ))
        if not rows.hasChildNodes()
            rows.innerHTML += generate_where_row(1)
    else if _.contains(classes, 'fa-plus')
        rows.innerHTML += generate_where_row( getID(document.getElementById('selectrows').lastChild) + 1 )

gen_fields_list = () ->
    fields.join(', ')

generate_where_row = (id) ->
    return  """
            <div class='fieldrow' id='fieldrow_#{id}'>
            <span>
                <div class='field'>
                    <input type='text' id='where_left_#{id}' placeholder='Field' required />
                    <span class="fa fa-question-circle">
                        <span>#{gen_fields_list()}</span>
                    </span>
                    <label for='where_left_#{id}'>Field</label>
                </div>
            </span>
            <span>
                <div class='field'>
                    <select required>
                        <option value=''>Operator</option>
                        <option value='='>is</option>
                        <option value='!'>is not</option>
                        <option value='<'>&lt;</option>
                        <option value='>'>&gt;</option>
                        <option value='~'>matches</option>
                    </select>
                    <label>Operator</label>
                </div>
            </span>
            <span>
                <div class='field'>
                    <input type='text' id='where_right_#{id}' placeholder='Comparison' required />
                    <label for='where_right_${id}'>Comparison</label>
                </div>
            </span>
            <span class="fa fa-minus" id='where_remove_#{id}'></span>
            <span class="fa fa-plus" id='where_add_#{id}'></span>
            </div>
            """
