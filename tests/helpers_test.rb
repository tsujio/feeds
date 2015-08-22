# -*- coding: utf-8 -*-

require 'test-unit'
require './helpers'

class HelpersTest < Test::Unit::TestCase
  sub_test_case '#sanitize' do
    data(
      'p' => ['<p>foo</p>', '<p id="p">foo</p>'],
      'br' => ['foo<br>', 'foo<br>'],
      'ul' => ['<ul><li>foo</li></ul>', '<ul id="ul"><li id="li">foo</li></ul>'],
      'ol' => ['<ol><li>foo</li></ol>', '<ol id="ol"><li id="li">foo</li></ol>'],
      'dl' => ['<dl><dt>foo</dt><dd>bar</dd></dl>', '<dl id="dl"><dt id="dt">foo</dt><dd id="dd">bar</dd></dl>'],
      'a http' => ['<a href="http://example.com">foo</a>', '<a href="http://example.com" title="title">foo</a>'],
      'a https' => ['<a href="https://example.com">foo</a>', '<a href="https://example.com" title="title">foo</a>'],
      'a javascript' => ['<a>foo</a>', '<a href="javascript:alert(\'xss!\')" title="title">foo</a>'],
      'img http' => ['<img src="http://example.com">', '<img src="http://example.com">'],
      'img https' => ['<img src="https://example.com">', '<img src="https://example.com">'],
      'img attrs' => ['<img alt="foo" width="100" height="100">', '<img alt="foo" width="100" height="100">'],
      'blockquote' => ['<blockquote title="foo" cite="http://example.com">foo</blockquote>', '<blockquote title="foo" cite="http://example.com">foo</blockquote>'],
      'blockquote javascript' => ['<blockquote title="foo">foo</blockquote>', '<blockquote title="foo" cite="javascript:alert(\'xss!\')">foo</blockquote>'],
      'callback' => ['<p>foo</p>', '<p onmouseover="alert(\'xss!\')">foo</p>'],
      'html' => ['foo', '<html>foo</html'],
      'body' => ['foo', '<body>foo</body>'],
      'script' => ['foo', '<script>foo</script>'],
      'span' => ['foo', '<span>foo</span>'],
    )
    def test_sanitize(data)
      expected, actual = data
      assert_equal(expected, Helpers.san(actual))
    end
  end
end
