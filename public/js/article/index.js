$(function() {
  var set_handlers = function() {
    var article = $(this);
    var article_id = article.find('.article-header .article-id').text();

    // Auto marking as read by scrolling
    article.find('.bottom-of-article').bind('inview', function(e, isInView) {
      var bottom = $(this);

      if (isInView) {
        $.ajax({
          type: 'PATCH',
          url: '/article/' + article_id,
          data: {read: true},
          success: function() {
            bottom.unbind('inview');

            console.log('read: ' + article_id);
          },
          error: function(xhr, status, error) {
            console.log(error);
          }
        });
      }
    });

    // Save article
    article.find('.btn-save').click(function() {
      $.ajax({
        type: 'PATCH',
        url: '/article/' + article_id,
        data: {saved: true},
        success: function() {
          console.log('save: ' + article_id);
        },
        error: function(xhr, status, error) {
          console.log(error);
        }
      });
    });

    // Keep article unread
    article.find('.btn-keep-unread').click(function() {
    });
  };

  $('article').each(set_handlers);

  // Mark all as read
  $('#btn-mark-all-as-read').click(function() {
    $.ajax({
      type: 'PATCH',
      url: '/article',
      data: {read: true},
      success: function() {
        console.log('marked all as read');
      },
      error: function(xhr, status, error) {
        console.log(error);
      }
    });
  });

  // Read more
  $('#btn-read-more').click(function() {
    var last_article_id = $('article.article').last().find('.article-id').text();
    $.ajax({
      type: 'GET',
      url: '/article' + location.search,
      data: {last_article_id: last_article_id},
      dataType: 'html',
      success: function(articles) {
        var articles = $(articles);
        articles.each(set_handlers);
        $('#articles-area').append(articles);
      },
      error: function(xhr, status, error) {
        console.log(error);
      }
    });
  });
});
