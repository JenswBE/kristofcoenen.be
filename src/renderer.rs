use askama::Template;
use reqwest::Url;
use std::fs;
use std::path::Path;

pub struct Renderer<'a> {
    output_path: &'a Path,
    base_url: Url,
    sitemap_urls: Vec<String>,
}

#[derive(Template)]
#[template(path = "robots.txt.jinja2", ext = "txt")]
struct TemplateRobots {
    sitemap_url: Url,
}

#[derive(Template)]
#[template(path = "sitemap.xml.jinja2", ext = "xml")]
struct TemplateSitemap<'a> {
    sitemap_urls: &'a Vec<String>,
}

impl<'a> Renderer<'a> {
    pub fn new(base_url: Url, output_path: &'a Path) -> Self {
        Renderer {
            base_url,
            sitemap_urls: vec![],
            output_path,
        }
    }

    pub fn render_page<P: AsRef<Path>>(
        &mut self,
        path: P,
        content: &str,
        sitemap_url: Option<String>,
    ) {
        let output_path = self.output_path.join(path);
        let output_dir = output_path.parent().unwrap();
        fs::create_dir_all(output_dir).expect("Failed to create dir");
        fs::write(output_path, content).expect("Failed to write rendered template to file");

        if let Some(sitemap_url) = sitemap_url {
            self.sitemap_urls.push(sitemap_url.to_string());
        }
    }

    /// Renders robots.txt into output root
    pub fn render_robots_txt(&self) {
        let output_path = self.output_path.join("robots.txt");
        fs::write(
            output_path,
            TemplateRobots {
                sitemap_url: self.base_url.join("/sitemap.xml").unwrap(),
            }
            .render()
            .expect("Unable to render robots.txt template"),
        )
        .expect("Failed to write rendered template to robots.txt");
    }

    /// Render sitemap.xml in output root based on previously rendered templates (should be called after templates).
    pub fn render_sitemap_xml(&self) {
        let output_path = self.output_path.join("sitemap.xml");
        fs::write(
            output_path,
            TemplateSitemap {
                sitemap_urls: &self.sitemap_urls,
            }
            .render()
            .expect("Unable to render robots.txt template"),
        )
        .expect("Failed to write rendered template to robots.txt");
    }
}
