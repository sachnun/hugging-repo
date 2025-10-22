# hugging-repo

GitHub action to sync your repository to Hugging Face spaces, models, or datasets.

**🚀 Pure Bash Implementation** - No Python dependencies required!

## Usage

Add your Hugging Face token as a GitHub Secret (e.g., `HF_TOKEN`):

```yaml
name: Deploy to huggingface

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: sachnun/hugging-repo@v1
        with:
          hf_token: ${{ secrets.HF_TOKEN }}
          # huggingface_repo: 'my-repo' # Optional, defaults to GitHub repo name
          # repo_type: 'space'           # Optional: space, model, or dataset (default: space)
          # space_sdk: 'gradio'          # Optional: gradio, streamlit, static, or docker (auto-detects docker if Dockerfile exists)
          # private: false               # Optional: create as private repo
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.