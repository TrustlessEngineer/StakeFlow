# Contributing to StakeFlow

Thank you for your interest in contributing to StakeFlow! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/stakeflow.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Submit a pull request

## Development Setup

See the [README.md](README.md) for setup instructions.

## Code Standards

### Solidity

- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use `forge fmt` for formatting
- Add NatSpec comments for all public functions
- Maintain test coverage > 90%

### TypeScript/React

- Use ESLint and Prettier
- Follow component-based architecture
- Add TypeScript types for all props
- Use custom hooks for Web3 interactions

### Python

- Follow PEP 8
- Use Black for formatting
- Add type hints
- Include docstrings

## Testing

All contributions must include tests:

```bash
# Smart contract tests
forge test

# Frontend tests
npm test

# Backend tests
pytest
```

## Pull Request Process

1. Update documentation if needed
2. Add tests for new features
3. Ensure all tests pass
4. Update CHANGELOG.md
5. Request review from maintainers

## Commit Message Format

```
type(scope): subject

body (optional)

footer (optional)
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Example:
```
feat(staking): add auto-compound functionality

Implements reward compounding for pools where staking
and reward tokens are the same.

Closes #123
```

## Areas for Contribution

### High Priority

- Gas optimization improvements
- Additional test coverage
- Documentation improvements
- Security enhancements

### Medium Priority

- New pool types
- Analytics features
- UI/UX improvements
- Performance optimizations

### Good First Issues

- Typos and documentation fixes
- Code comments
- Test cases
- Example scripts

## Code Review

All submissions require review before merging. We aim to respond within:

- 24 hours for small fixes
- 48 hours for features
- 72 hours for significant changes

## Community

- Discord: [link]
- Twitter: [@StakeFlow](https://twitter.com/stakeflow)
- Forum: [link]

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
