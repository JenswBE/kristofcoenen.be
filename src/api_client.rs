use cynic::QueryBuilder;
use rayon::prelude::*;
use reqwest::{blocking, header, Url};
use std::fs::{self, File};
use std::io::copy;
use std::path::Path;

pub struct Client {
    http_client: blocking::Client,
    base_url: Url,
    assets_queue: Vec<Asset>,
}

struct Asset {
    id: String,
    extension: &'static str,
    key: Option<&'static str>,
}

impl Client {
    pub fn build(base_url: Url, api_token: &str) -> Self {
        let mut headers = header::HeaderMap::new();
        let mut auth_value = header::HeaderValue::from_str(&("Bearer ".to_string() + api_token))
            .expect("Unable to set authentication header");
        auth_value.set_sensitive(true);
        headers.insert(header::AUTHORIZATION, auth_value);
        let http_client = reqwest::blocking::Client::builder()
            .default_headers(headers)
            .connection_verbose(true)
            .build()
            .expect("Failed to create reqwest client");

        Client {
            http_client,
            base_url,
            assets_queue: vec![],
        }
    }

    pub fn get_general_settings(&self) -> GeneralSettings {
        use cynic::http::ReqwestBlockingExt;
        let graphql_url = self.base_url.join("/graphql").unwrap();
        let resp = self
            .http_client
            .post(graphql_url)
            .run_graphql(GeneralSettingsQuery::build(()))
            .expect("Failed to fetch general settings");
        if let Some(errors) = resp.errors {
            for e in errors {
                log::error!("GraphQL query GeneralSettingsQuery returned error(s): {e}")
            }
        };
        resp.data
            .expect("No general settings returned")
            .general_settings
            .unwrap()
    }

    pub fn get_realisations(&self) -> Vec<Realisation> {
        use cynic::http::ReqwestBlockingExt;
        let graphql_url = self.base_url.join("/graphql").unwrap();
        let resp = self
            .http_client
            .post(graphql_url)
            .run_graphql(RealisationsQuery::build(()))
            .expect("Failed to fetch realisations");
        if let Some(errors) = resp.errors {
            for e in errors {
                log::error!("GraphQL query RealisationsQuery returned error(s): {e}")
            }
        };
        resp.data
            .expect("No realisations returned")
            .realisations
            .into_iter()
            .map(Realisation::from)
            .collect()
    }

    pub fn queue_asset(&mut self, id: String, extension: &'static str, key: Option<&'static str>) {
        self.assets_queue.push(Asset { id, extension, key })
    }

    pub fn download_assets_queue<P: AsRef<Path> + Sync>(
        &self,
        output_dir: P,
        cache_dir: Option<P>,
    ) {
        fs::create_dir_all(&output_dir).expect("Failed to create output assets dir");
        if let Some(path_cache_assets) = &cache_dir {
            log::info!(
                "Caching enabled to folder \"{}\"",
                cache_dir.as_ref().unwrap().as_ref().display()
            );
            fs::create_dir_all(&path_cache_assets).expect("Failed to create assets cache dir");
        }

        self.assets_queue.par_iter().for_each(|asset| {
            self.download_asset(
                output_dir.as_ref(),
                &asset.id,
                &asset.extension,
                asset.key,
                cache_dir.as_ref().map(|d| d.as_ref()),
            )
        });
    }

    fn download_asset<P: AsRef<Path>>(
        &self,
        output_dir: P,
        id: &str,
        extension: &str,
        key: Option<&str>,
        cache_dir: Option<P>,
    ) {
        // Derive filename and paths
        let filename = format!(
            "{}{}.{}",
            id,
            key.map_or("".to_string(), |k| "-".to_string() + k),
            extension
        );
        let output_path = output_dir.as_ref().join(&filename);
        let cache_path = cache_dir.map(|p| p.as_ref().join(&filename));

        // Try get asset from cache if enabled
        if let Some(cache_path) = &cache_path {
            if cache_path
                .try_exists()
                .expect("Unable to check if validated file exists")
            {
                log::info!("Reusing asset {} from cache ...", filename);
                fs::copy(cache_path, output_path).expect("Failed to copy cached version");
                return;
            }
        }

        // Fetch asset
        let asset_url = self
            .base_url
            .join(&format!("/assets/{}/{}", id, filename))
            .unwrap();
        log::info!("Downloading asset {} ...", filename);
        let mut req = self.http_client.get(asset_url.as_ref());
        if let Some(key) = key {
            req = req.query(&[("key", key), ("download", "true")]);
        }
        let mut resp = req.send().expect("Unable to get asset");
        if !resp.status().is_success() {
            log::error!(
                "Failed to fetch asset from {}: {}",
                asset_url,
                resp.text().unwrap()
            );
            panic!("Failed to fetch asset")
        }
        {
            let mut file = File::create(&output_path)
                .expect(&format!("Unable to create file: {}", output_path.display()));
            let file_size = copy(&mut resp, &mut file).expect("Unable to write asset to file");
            if file_size == 0 {
                log::error!(
                    "Fetching asset {} (status {}) returned an empty body",
                    asset_url,
                    resp.status().as_u16(),
                );
                panic!("Fetched asset is empty")
            }
            file.sync_all().expect("Failed to flush asset file");
        }

        // Feed cache if enabled
        if let Some(cache_path) = &cache_path {
            fs::copy(output_path, cache_path).expect("Failed to copy asset to cache");
        }
    }
}

// Generated with https://generator.cynic-rs.dev/
#[cynic::schema("directus")]
mod schema {}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "Query")]
pub struct GeneralSettingsQuery {
    #[cynic(rename = "general_settings")]
    pub general_settings: Option<GeneralSettings>,
}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "general_settings")]
pub struct GeneralSettings {
    pub email: String,
    #[cynic(rename = "phone_number")]
    pub phone_number: String,
    #[cynic(rename = "vat_number")]
    pub vat_number: String,
}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "Query")]
struct RealisationsQuery {
    realisations: Vec<ApiRealisation>,
}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "realisations")]
struct ApiRealisation {
    name: String,
    slug: String,
    #[cynic(rename = "main_image")]
    pub main_image: Option<DirectusFile>,
    #[cynic(rename = "additional_images", flatten)]
    pub additional_images: Vec<RealisationsFile>,
}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "realisations_files")]
pub struct RealisationsFile {
    #[cynic(rename = "directus_files_id")]
    pub directus_files_id: Option<DirectusFile>,
}

#[derive(cynic::QueryFragment, Debug)]
#[cynic(graphql_type = "directus_files")]
pub struct DirectusFile {
    pub id: cynic::Id,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_realisations_query_graphql_output() {
        use cynic::QueryBuilder;
        let operation = RealisationsQuery::build(());
        insta::assert_snapshot!(operation.query);
    }
}

pub struct Realisation {
    pub name: String,
    pub slug: String,
    pub main_image: String,
    pub secondary_images: Vec<String>,
}

impl From<ApiRealisation> for Realisation {
    fn from(item: ApiRealisation) -> Self {
        Self {
            name: item.name,
            slug: item.slug,
            main_image: item
                .main_image
                .expect("Realisation must have a main image")
                .id
                .into_inner(),
            secondary_images: item
                .additional_images
                .into_iter()
                .map(|image| {
                    image
                        .directus_files_id
                        .expect("Additional image file must have Directus file ID")
                        .id
                        .into_inner()
                })
                .collect(),
        }
    }
}
