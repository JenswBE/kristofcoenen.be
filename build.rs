fn main() {
    cynic_codegen::register_schema("directus")
        .from_sdl_file("schemas/directus.graphql")
        .unwrap()
        .as_default()
        .unwrap();
}
