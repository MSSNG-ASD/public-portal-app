$(function() {

  var form = $('.edit_user');
  form.find('input[type=checkbox]').click(function() {
    $(form).closest('form').submit();
  });

  $('#default-reset').click(function() {
    $('.default-setting').prop('checked', true);
    $('.non-default-setting').prop('checked', false);
    $(form).closest('form').submit();
  });

  $('#preferences-modal').on('hidden.bs.modal', function() {
    location.reload();
  });

});
