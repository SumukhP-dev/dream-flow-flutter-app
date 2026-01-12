# Contributing to Dream Flow

Thank you for your interest in contributing to Dream Flow! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect different viewpoints and experiences

## Getting Started

1. **Fork the repository**
2. **Clone your fork:**
   ```bash
   git clone https://github.com/yourusername/dream-flow.git
   cd dream-flow
   ```
3. **Create a branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Backend

```bash
cd backend_fastapi
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

### Web App

```bash
pnpm install
cd dream-flow-app/website
pnpm dev
```

### Mobile App

```bash
cd dream-flow-app/app
flutter pub get
flutter run
```

## Making Changes

1. **Make your changes** in your feature branch
2. **Write tests** for new functionality
3. **Update documentation** if needed
4. **Ensure code quality:**
   - Follow existing code style
   - Run linters/formatters
   - Write clear commit messages

## Testing

Before submitting a PR, ensure:

- [ ] All tests pass (`pytest` for backend, `flutter test` for mobile)
- [ ] Code follows project style guidelines
- [ ] Documentation is updated
- [ ] No sensitive data is committed

## Submitting Changes

1. **Commit your changes:**
   ```bash
   git commit -m "Add: description of your changes"
   ```

2. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Open a Pull Request** on GitHub

## Pull Request Guidelines

- Provide a clear description of changes
- Reference any related issues
- Include screenshots for UI changes
- Ensure CI checks pass
- Request review from maintainers

## Code Style

- **Python**: Follow PEP 8, use type hints
- **TypeScript/JavaScript**: Use ESLint/Prettier config
- **Dart**: Follow Dart style guide
- **Commit messages**: Use conventional commits format

## Questions?

Feel free to open an issue for questions or discussions about contributions.

Thank you for contributing! 🎉

