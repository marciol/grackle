require "grackle"

local function set_up_templates()
  local templates = {}
  templates["Main HTML layout"] =
    Template.new { path = "t/layouts/main.html.haml", file = "---\nsite.uri = 'http://example.com/'---\n%body= content\n" }

  templates["Main non-HTML layout"] =
    Template.new { path = "t/layouts/main.css.cosmo", file = "/* CSS */\n$content" }

  templates["Sub-layout"] =
    Template.new { path = "t/layouts/posts.html.haml", file = "post= content\n" }

  templates["Haml content"] =
    Template.new { path = "t/pages/index.haml", file = "---\npage.title = 'Welcome'\n---\n%h1= page.title\n" }

  templates["Cosmo content"] =
    Template.new { path = "t/pages/stylesheets/screen.css.cosmo", file = "body { color: #000; }\n" }

  templates["Cosmo content with no layout"] =
    Template.new { path = "t/pages/stylesheets/reset.css.cosmo", file = "---\npage.layout = false\n---\n" }

  templates["Markdown content"] =
    Template.new { path = "t/pages/about.markdown", file = "## About\n" }

  templates["Feed entry 3"] =
    Template.new { path = "t/pages/posts/feed-entry-3.markdown", file = "---\npage.title = 'Three'\npage.published = '2009-12-31'\n---\n## Three\n" }

  templates["Feed entry 2"] =
    Template.new { path = "t/pages/posts/feed-entry-2.markdown", file = "---\npage.title = 'Two'\npage.published = '2009-01-03'\n---\n## Two\n" }

  templates["Feed entry 1"] =
    Template.new { path = "t/pages/posts/feed-entry-1.markdown", file = "---\npage.title = 'One'\npage.published = '2009-01-01'\n---\n## One\n" }

  templates["Haml partial"] =
    Template.new { path = "t/partials/links.haml", file = "%a(href='http://example.org') Example" }

  grackle.source_dir = 't'
  grackle.templates = {}
  for _, t in pairs(templates) do table.insert(grackle.templates, t) end
  return templates
end

context("The Grackle app", function()

  it("can load a directory of template files", function()
    assert_not_nil(grackle.get_templates("sample"))
  end)

  it("performs initialization tasks", function()
    grackle.init("sample")
    assert_greater_than(#grackle.templates, 0)
  end)

  it("generates the site", function()
    grackle.OUTPUT_DIR = "/tmp/grackle-test-tmp"
    grackle.generate_site "sample"
    os.execute("rm -rf /tmp/grackle-test-tmp")
    assert_true(true)
  end)
end)

context("Grackle feeds", function()

  local feeds

  before(function()
    local templates = set_up_templates()
    local pages = {}
    for t in table.each(grackle.templates, Template.is_content) do
      table.insert(pages, t:to_page())
    end
    feeds = grackle.get_feeds(pages)
  end)

  they("are sorted by date descending", function()
    assert_equal("Three", feeds.posts.entries[1].title)
    assert_equal("Two", feeds.posts.entries[2].title)
    assert_equal("One", feeds.posts.entries[3].title)
  end)

end)

context("Grackle utils", function()
  they("can convert strings to date tables", function()
    local date = string.to_date("2001-01-02 03:04:05")
    assert_equal("2001", date.year)
    assert_equal("01", date.month)
    assert_equal("02", date.day)
    assert_equal("03", date.hour)
    assert_equal("04", date.min)
    assert_equal("05", date.sec)
  end)
end)

context("Grackle utils", function()
  they("can convert strings to rfc3339 dates", function()
    assert_equal("2009-01-01T12:01:02Z", grackle.helpers.rfc3339("2009-01-01 12:01:02"))
    assert_equal("2009-01-01T00:00:00Z", grackle.helpers.rfc3339("2009-01-01"))
  end)
end)

context("Grackle helpers", function()
  they("add links with attributes", function()
    assert_equal('<a href="a" id="b">c</a>', grackle.helpers.link("c", "a", {id = "b"}))
  end)
end)

context("Grackle templates", function()

  local t

  setup(function()
    t = set_up_templates()
  end)

  they("have a base name", function()
    assert_equal("index", t["Haml content"]:get_base_name())
  end)

  they("have a format, defaulting to 'html'", function()
    assert_equal("html", t["Haml content"]:get_format())
  end)

  they("have a renderer taken from the file extension", function()
    assert_equal("haml", t["Haml content"]:get_renderer())
  end)

  they("have a layout renderer", function()
    assert_equal("haml", t["Haml content"]:get_layout_renderer())
  end)

  they("have a dir matching its relative location on disk", function()
    assert_equal("t/pages", t["Haml content"]:get_dir())
  end)

  they("have a dir matching the name of its parent dir", function()
    assert_equal("pages", t["Haml content"]:get_dir_name())
  end)

  they("have a site_dir matching its relative target location on disk", function()
    assert_equal("", t["Haml content"]:get_site_dir())
  end)

  they("have a site_path matching target file name and relative uri", function()
    assert_equal("index.html", t["Haml content"]:get_site_path())
  end)

  they("have a path matching their location relative to the source dir", function()
    assert_equal("pages/index.haml", t["Haml content"]:get_path())
  end)

  they("have contents", function()
    assert_equal("%h1= page.title", t["Haml content"]:get_contents())
  end)

  they("have headers", function()
    assert_equal("page.title = 'Welcome'", t["Haml content"]:get_headers())
  end)

  they("can evaluate their headers", function()
    t["Haml content"]:eval_headers()
    assert_equal("Welcome", t["Haml content"].page_config.title)
  end)

  context("a content template", function()

    it("specifies that it is content", function()
      assert_true(t["Haml content"]:is_content())
      assert_false(t["Main HTML layout"]:is_content())
      assert_false(t["Haml partial"]:is_content())
    end)

    it("should default to a main layout matching its renderer", function()
      assert_equal(t["Main HTML layout"], t["Haml content"]:get_layout())
      assert_equal(t["Main non-HTML layout"], t["Cosmo content"]:get_layout())
    end)

    it("if Markdown, should use the default layout renderer", function()
      assert_equal(grackle.DEFAULT_RENDERER, t["Markdown content"]:get_layout_renderer())
    end)

    it("can use headers to specify layout-less rendering", function()
      assert_nil(t["Cosmo content with no layout"]:get_layout())
    end)

    context("for rendering", function()

      it("can be Cosmo", function()
        local rendered = grackle.render_with_layout(t["Cosmo content"]):gsub("\n", "")
        assert_equal("/* CSS */body { color: #000; }", rendered)
      end)

      it("can be Haml", function()
        local rendered = grackle.render_with_layout(t["Haml content"]):gsub("\n", "")
        assert_equal("<body><h1>Welcome</h1></body>", rendered)
      end)

      it("can be Markdown", function()
        local rendered = grackle.render_with_layout(t["Markdown content"]):gsub("\n", "")
        assert_equal("<body><h2>About</h2></body>", rendered)
      end)

    end)

  end)

  context("a layout template", function()

    it("specifes that it is a layout", function()
      assert_false(t["Haml content"]:is_layout())
      assert_true(t["Main HTML layout"]:is_layout())
      assert_true(t["Main non-HTML layout"]:is_layout())
      assert_false(t["Haml partial"]:is_layout())
    end)

    it("can be a sub-layout", function()
      assert_equal(t["Sub-layout"]:get_layout(), t["Main HTML layout"])
    end)

    it("should not have a layout if it is a main layout", function()
      assert_nil(t["Main HTML layout"]:get_layout())
      assert_nil(t["Main non-HTML layout"]:get_layout())
    end)

    context("for rendering", function()

      it("can be Cosmo", function()
        local rendered = grackle.render_with_layout(t["Main non-HTML layout"]):gsub("\n", "")
        assert_equal("/* CSS */", rendered)
      end)

      it("can be Haml", function()
        local rendered = grackle.render_with_layout(t["Main HTML layout"]):gsub("\n", "")
        assert_equal("<body></body>", rendered)
      end)

    end)

  end)

  context("a partial template", function()
    it("specifes that it is a partial", function()
      assert_false(t["Haml content"]:is_partial())
      assert_false(t["Main HTML layout"]:is_partial())
      assert_true(t["Haml partial"]:is_partial())
    end)
  end)

end)
