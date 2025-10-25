# watch-cli

A robust, modular command-line tool for streaming anime, movies, and TV shows. Built with a multi-provider architecture for maximum content availability and resilience.

## Features

- **Multi-Provider Support**: Automatically queries multiple sources in fallback order
- **Interactive Selection**: Fast, intuitive content selection using `fzf`
- **Multiple Media Types**: Support for Anime, Movies, and TV Shows
- **Quality Streaming**: Direct stream URLs with proper headers
- **Torrent Streaming**: High-quality content via peerflix (optional)
- **Configurable**: Extensive configuration options
- **Cross-Platform**: Works on Linux, macOS, and WSL

## Supported Providers

### Anime
- **AllAnime**: Primary anime provider with comprehensive library

### Movies & TV Shows
- **Internet Archive**: Free, legal content with direct streaming
- **Goku.to**: Modern content with multiple quality options
- **Peerflix**: High-quality torrent streaming (requires VPN)

## Installation

### Prerequisites

Ensure you have the following dependencies installed:

```bash
# Core dependencies
sudo apt install curl fzf jq  # Ubuntu/Debian
# or
brew install curl fzf jq       # macOS

# Media player (choose one)
sudo apt install mpv           # Recommended
# or
sudo apt install vlc

# For torrent streaming (optional)
npm install -g peerflix
```

### Install watch-cli

```bash
# Clone the repository
git clone https://github.com/yourusername/watch-cli.git
cd watch-cli

# Make the script executable
chmod +x watch-cli

# Create symlink for global access (optional)
sudo ln -s $(pwd)/watch-cli /usr/local/bin/watch-cli
```

## Usage

### Basic Usage

```bash
# Start the interactive interface
./watch-cli

# Or with symlink
watch-cli
```

### Command Line Options

```bash
# Skip media type selection
watch-cli --anime          # Go directly to anime search
watch-cli --movie          # Go directly to movie search
watch-cli --tv             # Go directly to TV show search

# Quality and language preferences
watch-cli --quality 1080p --language en

# Disable torrent streaming
watch-cli --no-torrent

# Show help
watch-cli --help
```

### Environment Variables

```bash
# Set default player
export WATCH_CLI_PLAYER="vlc"

# Set default quality
export WATCH_CLI_QUALITY="720p"

# Set default language
export WATCH_CLI_LANGUAGE="en"

# Disable torrent streaming
export ENABLE_TORRENT="false"
```

## Configuration

Create a configuration file at `~/.config/watch-cli/config`:

```bash
# Copy example configuration
cp config.example ~/.config/watch-cli/config

# Edit configuration
nano ~/.config/watch-cli/config
```

### Configuration Options

```bash
# Media Player
WATCH_CLI_PLAYER="mpv"              # mpv or vlc

# Quality Preferences
WATCH_CLI_QUALITY="720p"           # 360p, 480p, 720p, 1080p

# Language Preferences
WATCH_CLI_LANGUAGE="en"            # en, jp, es, fr, de, etc.

# Provider Settings
ENABLE_TORRENT="true"              # Enable/disable torrent streaming
ENABLE_ALLANIME="true"             # Enable/disable AllAnime
ENABLE_INTERNET_ARCHIVE="true"     # Enable/disable Internet Archive
ENABLE_GOKU="true"                 # Enable/disable Goku.to
ENABLE_PEERFLIX="true"             # Enable/disable Peerflix

# Logging
ENABLE_LOGGING="true"               # Enable/disable logging
LOG_LEVEL="INFO"                    # DEBUG, INFO, WARNING, ERROR
```

## Workflow

1. **Media Type Selection**: Choose between Anime, Movie, or TV Show
2. **Search**: Enter your search query
3. **Content Selection**: Browse and select from available results
4. **Episode Selection**: For anime/TV shows, select the desired episode
5. **Streaming**: Content automatically opens in your configured media player

## Provider Details

### AllAnime Provider
- **Source**: AllAnime GraphQL API
- **Content**: Anime series and movies
- **Quality**: Multiple quality options
- **Languages**: Sub and dub available
- **Headers**: Automatic referer header handling

### Internet Archive Provider
- **Source**: archive.org
- **Content**: Public domain movies and TV shows
- **Quality**: Varies by source
- **Legal**: Free and legal content
- **Direct Streaming**: No additional processing required

### Goku.to Provider
- **Source**: Goku.to API
- **Content**: Modern movies and TV shows
- **Quality**: Multiple quality options
- **Headers**: Automatic referer header handling
- **Fallback**: Secondary provider for recent content

### Peerflix Provider
- **Source**: Torrent sites (The Pirate Bay, 1337x)
- **Content**: High-quality movies and TV shows
- **Quality**: Often highest available
- **Legal Notice**: Requires VPN for legal compliance
- **Dependencies**: Node.js and peerflix required

## Troubleshooting

### Common Issues

**No results found:**
- Try different search terms
- Check if providers are enabled in configuration
- Verify internet connection

**Stream won't play:**
- Check if media player is properly installed
- Try different quality settings
- Verify headers are being passed correctly

**Peerflix not working:**
- Install Node.js: `curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs`
- Install peerflix: `npm install -g peerflix`
- Check VPN connection for legal compliance

**Permission denied:**
- Make script executable: `chmod +x watch-cli`
- Check file permissions in cache directory

### Debug Mode

Enable debug logging:

```bash
# Set debug level in config
LOG_LEVEL="DEBUG"

# Or run with debug output
bash -x watch-cli
```

### Logs

Check logs for troubleshooting:

```bash
# View recent logs
tail -f ~/.config/watch-cli/watch-cli.log

# Clear logs
> ~/.config/watch-cli/watch-cli.log
```

## Legal Notice

This tool is for educational purposes only. Users are responsible for:

- Complying with local copyright laws
- Using VPN when accessing torrent content
- Respecting website terms of service
- Using only legal, authorized content sources

The Internet Archive provider offers free, legal content. Other providers may require VPN usage for legal compliance.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

### Adding New Providers

To add a new provider:

1. Create a new script in `providers/`
2. Implement the required interface:
   - `search <query> <media_type>`
   - `episodes <content_id>`
   - `stream <content_id> <episode>`
3. Update the main script to include the provider
4. Add documentation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [ani-cli](https://github.com/pystardust/ani-cli)
- AllAnime API integration
- Internet Archive for free content
- The open-source community

## Support

For support, please:

1. Check the troubleshooting section
2. Search existing issues
3. Create a new issue with:
   - Operating system and version
   - Error messages
   - Steps to reproduce
   - Configuration details
