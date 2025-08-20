use wikipedia_core::ArticleCategorizer;

pub struct HistoryCategorizer;

impl ArticleCategorizer for HistoryCategorizer {
    fn categorize(&self, title: &str, _content: &str) -> Vec<String> {
        let title_lower = title.to_lowercase();
        let mut categories = Vec::new();

        if title_lower.contains("war")
            || title_lower.contains("battle")
            || title_lower.contains("siege")
            || title_lower.contains("campaign")
            || title_lower.contains("conflict")
            || title_lower.contains("military")
        {
            categories.push("wars".to_string());
        }

        if title_lower.contains("empire")
            || title_lower.contains("kingdom")
            || title_lower.contains("dynasty")
            || title_lower.contains("emperor")
            || title_lower.contains("king")
            || title_lower.contains("queen")
        {
            categories.push("empires".to_string());
        }

        if title_lower.contains("ancient")
            || title_lower.contains("civilization")
            || title_lower.contains("bc")
            || title_lower.contains("egypt")
            || title_lower.contains("rome")
            || title_lower.contains("greece")
        {
            categories.push("ancient".to_string());
        }

        if title_lower.contains("medieval")
            || title_lower.contains("middle ages")
            || title_lower.contains("crusade")
            || title_lower.contains("feudal")
            || title_lower.contains("knight")
        {
            categories.push("medieval".to_string());
        }

        if title_lower.contains("president")
            || title_lower.contains("democracy")
            || title_lower.contains("republic")
            || title_lower.contains("revolution")
            || title_lower.contains("independence")
            || title_lower.contains("treaty")
        {
            categories.push("politics".to_string());
        }

        if title_lower.contains("culture")
            || title_lower.contains("heritage")
            || title_lower.contains("monument")
            || title_lower.contains("archaeology")
            || title_lower.contains("museum")
        {
            categories.push("culture".to_string());
        }

        categories
    }
}
