use clap::Parser;
use futures_util::TryStreamExt;
use std::path::PathBuf;
use tokio_util::io::StreamReader;
use wikipedia_core::{Article, Config, TopicFilter, generate};

mod history_categorizer;
use history_categorizer::HistoryCategorizer;

#[derive(Parser)]
#[command(
    name = "wikipedia-history-smg",
    about = "Generate History-focused Wikipedia StaticMCP",
    version = "1.0.0"
)]
struct Args {
    #[arg(short, long, help = "Input Wikipedia dump file or URL")]
    input: String,

    #[arg(short, long, help = "Output directory for StaticMCP files")]
    output: PathBuf,

    #[arg(short, long, default_value = "en", help = "Language code")]
    language: String,

    #[arg(short, long, help = "Maximum number of articles to process")]
    max_articles: Option<usize>,

    #[arg(long, help = "Generate exact match searches for all articles")]
    exact_matches: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    println!("🏛️  Wikipedia History StaticMCP Generator");
    println!("Language: {}", args.language);
    println!("Input: {}", args.input);
    println!("Output: {:?}", args.output);

    if let Some(max) = args.max_articles {
        println!("Max articles: {max}");
    }

    if args.input.starts_with("http://") || args.input.starts_with("https://") {
        generate_from_stream(&args.input, &args).await?;
    } else {
        let config = Config::new(PathBuf::from(&args.input), args.output)
            .language(args.language)
            .topic_filter(TopicFilter::History)
            .exact_matches(args.exact_matches);

        let config = if let Some(max) = args.max_articles {
            config.max_articles(max)
        } else {
            config
        };

        generate(config, HistoryCategorizer)?;
    }

    println!("✅ History StaticMCP generated successfully!");
    println!(
        "📚 Includes: Wars, empires, civilizations, historical figures, and cultural heritage"
    );
    println!("🌐 Deploy to: https://staticmcp.github.io/wikipedia-history");

    Ok(())
}

async fn generate_from_stream(url: &str, args: &Args) -> Result<(), Box<dyn std::error::Error>> {
    println!("🌐 Streaming from URL: {url}");

    let response = reqwest::get(url).await?;
    let stream = response.bytes_stream().map_err(std::io::Error::other);

    let reader = StreamReader::new(stream);

    std::fs::create_dir_all(&args.output)?;
    std::fs::create_dir_all(args.output.join("tools/get_article"))?;

    let is_bz2 = url.ends_with(".bz2");
    let topic_filter = Some(TopicFilter::History);
    let output_path = args.output.clone();
    let language = args.language.clone();
    let exact_matches = args.exact_matches;

    tokio::task::spawn_blocking(move || -> Result<(), std::io::Error> {
        use std::sync::{Arc, Mutex};

        let sync_reader = tokio_util::io::SyncIoBridge::new(reader);
        let parser = wikipedia_core::WikipediaParser::new(language.clone());
        let generator = Arc::new(Mutex::new(
            wikipedia_core::StaticMcpGenerator::new_streaming(
                output_path.clone(),
                language,
                HistoryCategorizer,
            ),
        ));

        let gen_clone = generator.clone();
        let handler =
            move |title: &str, article: &Article| -> Result<(), Box<dyn std::error::Error>> {
                gen_clone
                    .lock()
                    .unwrap()
                    .write_article_with_collision_handling(title, article)
            };

        parser
            .parse_streaming(Box::new(sync_reader), is_bz2, &topic_filter, handler)
            .map_err(|e| std::io::Error::other(format!("{e:?}")))?;

        generator
            .lock()
            .unwrap()
            .generate_metadata_only(exact_matches)
            .map_err(|e| std::io::Error::other(format!("{e:?}")))?;

        Ok(())
    })
    .await??;

    Ok(())
}
