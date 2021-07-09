jQuery ->
  $('.select2').select2({
    allowClear: true,
  });

jQuery ->
  $(".ajax-multi-select2").each ->
    url = $(this).data('url')
    options =
      multiple: $(this).data('multiple')
      minimum: parseInt($(this).data('minimum'))
    $(this).ajaxSelect(url, options)

jQuery ->
  $(".ajax-multi-select2-submit").each ->
    url = $(this).data('url')
    options =
      multiple: $(this).data('multiple')
      minimum: parseInt($(this).data('minimum'))
    $(this).ajaxSelect(url, options)

jQuery ->
  $('.ajax-multi-select2-submit').on 'keyup', (e) ->
    if e.keyCode == 13
      $(this).closest('form').submit()