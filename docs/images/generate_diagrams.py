#!/usr/bin/env python3
"""
Generate architecture diagrams from Mermaid definitions.

Requirements:
    pip install playwright
    playwright install chromium

Usage:
    python generate_diagrams.py
"""

import subprocess
import sys
from pathlib import Path


MERMAID_CLI_INSTRUCTIONS = """
To generate diagrams, install mermaid-cli:

    npm install -g @mermaid-js/mermaid-cli

Then run:
    mmdc -i architecture.mmd -o architecture.png
    mmdc -i sequence.mmd -o sequence.png
    mmdc -i dataflow.mmd -o dataflow.png

Or use online tools:
    1. Copy Mermaid code from docs/architecture.md
    2. Visit https://mermaid.live/
    3. Paste code and export as PNG/SVG
"""


def check_mmdc():
    """Check if mermaid-cli is installed."""
    try:
        subprocess.run(["mmdc", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def create_mermaid_files():
    """Create standalone Mermaid files from architecture documentation."""
    
    # Architecture diagram
    architecture_mmd = """graph TB
    subgraph "Client Layer"
        Browser[Web Browser]
        Mobile[Mobile Device]
    end
    
    subgraph "Azure CDN / Front Door" 
        CDN[Azure CDN/Front Door]
    end
    
    subgraph "Presentation Layer"
        WebApp[React Frontend<br/>App Service]
    end
    
    subgraph "API Layer"
        API[FastAPI Backend<br/>App Service]
        APICache[Redis Cache<br/>Optional]
    end
    
    subgraph "Integration Layer"
        Translator[Azure AI Translator<br/>Cognitive Services]
        Storage[Azure Storage<br/>Blobs & Tables]
        KeyVault[Azure Key Vault<br/>Secrets]
    end
    
    subgraph "Observability Layer"
        AppInsights[Application Insights]
        LogAnalytics[Log Analytics]
        Alerts[Azure Monitor Alerts]
    end
    
    Browser --> CDN
    Mobile --> CDN
    CDN --> WebApp
    WebApp --> API
    API --> APICache
    API --> Translator
    API --> Storage
    API --> KeyVault
    API --> AppInsights
    WebApp --> AppInsights
    Translator --> AppInsights
    AppInsights --> LogAnalytics
    LogAnalytics --> Alerts
    
    style Translator fill:#0078d4
    style KeyVault fill:#ffb900
    style AppInsights fill:#00bcf2
"""

    # Sequence diagram
    sequence_mmd = """sequenceDiagram
    actor User
    participant FE as Frontend (React)
    participant API as Backend (FastAPI)
    participant KV as Key Vault
    participant TR as Translator API
    participant ST as Storage
    participant AI as App Insights
    
    User->>FE: Enter text to translate
    FE->>AI: Track page view
    FE->>API: POST /api/v1/translate
    
    alt First Request (Cold Start)
        API->>KV: Get Translator credentials
        KV-->>API: Return credentials
    end
    
    API->>AI: Track request start
    API->>TR: POST /translate<br/>(with auth headers)
    
    alt Success
        TR-->>API: Return translations
        API->>ST: Store translation record
        API->>AI: Track success + metrics
        API-->>FE: Return result
        FE->>AI: Track translation event
        FE->>User: Display translation
    else Rate Limited
        TR-->>API: 429 Too Many Requests
        API->>API: Exponential backoff
        API->>TR: Retry request
        TR-->>API: Return translations
        API-->>FE: Return result
    else Error
        TR-->>API: Error response
        API->>AI: Track exception
        API-->>FE: Return error
        FE->>User: Display error message
    end
"""

    # Data flow diagram
    dataflow_mmd = """flowchart LR
    A[User Input] --> B{Language<br/>Detected?}
    B -->|No| C[Detect Language API]
    B -->|Yes| D[Validate Input]
    C --> D
    D --> E{In Cache?}
    E -->|Yes| F[Return Cached]
    E -->|No| G[Translator API]
    G --> H[Store Result]
    H --> I[Update Metrics]
    I --> J[Return to User]
    F --> J
"""

    images_dir = Path(__file__).parent
    
    files = {
        "architecture.mmd": architecture_mmd,
        "sequence.mmd": sequence_mmd,
        "dataflow.mmd": dataflow_mmd,
    }
    
    for filename, content in files.items():
        filepath = images_dir / filename
        filepath.write_text(content)
        print(f"Created: {filepath}")
    
    return files.keys()


def generate_diagrams(mermaid_files):
    """Generate PNG diagrams from Mermaid files."""
    images_dir = Path(__file__).parent
    
    for mmd_file in mermaid_files:
        input_path = images_dir / mmd_file
        output_path = images_dir / mmd_file.replace(".mmd", ".png")
        
        print(f"Generating {output_path}...")
        
        try:
            subprocess.run(
                ["mmdc", "-i", str(input_path), "-o", str(output_path), "-b", "transparent"],
                check=True,
                capture_output=True,
            )
            print(f"✓ Generated: {output_path}")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to generate {output_path}")
            print(f"Error: {e.stderr.decode()}")
            return False
    
    return True


def create_placeholder_images():
    """Create placeholder text files if diagram generation fails."""
    images_dir = Path(__file__).parent
    
    placeholder_files = [
        "architecture.png",
        "sequence.png", 
        "dataflow.png",
        "demo-screenshot-placeholder.png"
    ]
    
    for filename in placeholder_files:
        filepath = images_dir / filename
        if not filepath.exists():
            filepath.write_text(f"Placeholder for {filename}\nGenerate using: python generate_diagrams.py")
            print(f"Created placeholder: {filepath}")


def main():
    """Main function to generate diagrams."""
    print("Azure Translator Solution Accelerator - Diagram Generator")
    print("=" * 60)
    
    # Create Mermaid source files
    print("\n1. Creating Mermaid source files...")
    mermaid_files = create_mermaid_files()
    
    # Check if mermaid-cli is available
    print("\n2. Checking for mermaid-cli...")
    if not check_mmdc():
        print("✗ mermaid-cli (mmdc) not found")
        print(MERMAID_CLI_INSTRUCTIONS)
        print("\n3. Creating placeholder files...")
        create_placeholder_images()
        print("\n✓ Mermaid source files created. Install mmdc to generate diagrams.")
        return 1
    
    print("✓ mermaid-cli found")
    
    # Generate diagrams
    print("\n3. Generating diagrams...")
    if generate_diagrams(mermaid_files):
        print("\n✓ All diagrams generated successfully!")
        
        # Create demo screenshot placeholder
        images_dir = Path(__file__).parent
        demo_placeholder = images_dir / "demo-screenshot-placeholder.png"
        if not demo_placeholder.exists():
            demo_placeholder.write_text("Placeholder for demo screenshot\nReplace with actual screenshot")
            print(f"Created: {demo_placeholder}")
        
        return 0
    else:
        print("\n✗ Some diagrams failed to generate")
        print("Creating placeholder files...")
        create_placeholder_images()
        return 1


if __name__ == "__main__":
    sys.exit(main())

