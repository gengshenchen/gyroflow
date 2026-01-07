// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright © 2023 Adrian <adrian.eddy at gmail>

fn main() {
    // Download lens profiles if not already present
    let project_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    let db_path = format!("{project_dir}/../../resources/camera_presets/profiles.cbor.gz");

    // 只有文件不存在时才下载
    if !std::path::Path::new(&db_path).exists() {
        println!("cargo:warning=Lens profiles not found, attempting to download...");

        std::fs::create_dir_all(&format!("{project_dir}/../../resources/camera_presets")).unwrap();

        // ================= [新增] 代理配置逻辑 =================
        let proxy_url = std::env::var("https_proxy")
            .or_else(|_| std::env::var("HTTPS_PROXY"))
            .or_else(|_| std::env::var("http_proxy"))
            .or_else(|_| std::env::var("HTTP_PROXY"))
            .or_else(|_| std::env::var("all_proxy"))
            .or_else(|_| std::env::var("ALL_PROXY"))
            .ok();

        let mut config_builder = ureq::Agent::config_builder();

        if let Some(proxy_str) = proxy_url {
            println!("cargo:warning=Proxy detected for lens profiles: {}", proxy_str);
            if let Ok(proxy) = ureq::Proxy::new(&proxy_str) {
                config_builder = config_builder.proxy(Some(proxy));
            }
        }

        let agent = ureq::Agent::new_with_config(config_builder.build());
        // =======================================================

        let url = "https://github.com/gyroflow/lens_profiles/releases/latest/download/profiles.cbor.gz";

        // [修改] 使用 match 处理结果，而不是 if let 忽略错误
        match agent.get(url).call() {
            Ok(response) => {
                let mut body = response.into_body().into_reader();
                match std::fs::File::create(&db_path) {
                    Ok(mut file) => {
                        if let Err(e) = std::io::copy(&mut body, &mut file) {
                            println!("cargo:warning=Failed to write lens profiles: {:?}", e);
                            // 下载失败删除半成品文件
                            let _ = std::fs::remove_file(&db_path);
                        } else {
                            println!("cargo:warning=Lens profiles downloaded successfully!");
                        }
                    },
                    Err(e) => { panic!("Failed to create {db_path}: {e:?}"); }
                }
            },
            Err(e) => {
                // [关键] 打印具体的网络错误
                println!("cargo:warning=Failed to download lens profiles from {}: {:?}", url, e);
                println!("cargo:warning=Build will continue, but lens profiles will be missing.");
            }
        }
    }
}
