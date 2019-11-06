$(function() {
  var updated = false;
  var preferenceModal = $('#preferences-modal');
  var userPreferenceFeedback = preferenceModal.find('.feedback');
  var userPreferenceForm = preferenceModal.find('form.edit_user');
  var userPreferenceResetButton = $('#user-preference-reset');
  var userPreferenceCheckboxes = userPreferenceForm.find('input[type=checkbox]');
  var userPreferenceUpdateUrl = userPreferenceForm.attr('action');
  var userPreferenceFormToken = userPreferenceForm.find('input[name="authenticity_token"]').val();

  userPreferenceCheckboxes.click(function() {
    userPreferenceForm.submit();
  });

  userPreferenceResetButton.click(function(e) {
    e.preventDefault();
    userPreferenceForm.find('.default-setting').prop('checked', true);
    userPreferenceForm.find('.non-default-setting').prop('checked', false);
    userPreferenceForm.submit();
  });

  userPreferenceForm.on('submit', function(e) {
    e.preventDefault();
    userPreferenceFeedback.html('<span class="fa fa-upload"></span>');

    var submittingData = {
      authenticity_token: userPreferenceFormToken,
    };

    userPreferenceResetButton.attr('disabled', true);
    userPreferenceCheckboxes
      .attr('disabled', true)
      .each(function (idx, cb) {
        submittingData[cb.name] = cb.checked ? "1" : "0";
      })
    ;

    $.ajax({
      method: 'PATCH',
      url: userPreferenceUpdateUrl,
      data: submittingData,
      complete: function() {
        userPreferenceResetButton.removeAttr('disabled');
        userPreferenceCheckboxes.removeAttr('disabled');
        userPreferenceFeedback.html('<span class="fa fa-check"></span>');

        updated = true;
      }
    });
  });

  preferenceModal.on('hidden.bs.modal', function() {
    if (!updated) {
      return; // no reloading
    }

    $('#loading-indicator-container').removeClass('disabled');
    location.reload();
  });

});
