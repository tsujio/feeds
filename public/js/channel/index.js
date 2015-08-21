$(function() {
  $('.channel').each(function() {
    var chennel_id = $(this).find('.channel-id').text();

    $(this).find('.btn-delete').click(function() {
      $.ajax({
        type: 'DELETE',
        url: '/channel/' + channel_id,
        success: function(channel, dataType) {
          console.log('delete: ' + channel_id);
        },
        error: function(xhr, status, error) {
          console.log(error);
        }
      });
    });
  });
});

