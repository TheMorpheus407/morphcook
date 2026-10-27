from __future__ import annotations

from typing import Iterable


class PipelineError(Exception):
    """Base class for actionable maintainer-facing errors."""


class ConfigurationError(PipelineError):
    pass


class AgentError(PipelineError):
    pass


class AgentConfigurationError(AgentError):
    pass


class AgentProtocolError(AgentError):
    pass


class QualityGateError(PipelineError):
    pass


class CommitCancelled(PipelineError):
    pass


class SchemaValidationError(PipelineError):
    def __init__(self, subject: str, errors: Iterable[str]):
        self.subject = subject
        self.errors = tuple(errors)
        detail = "\n".join(f"  - {error}" for error in self.errors)
        super().__init__(f"{subject} failed schema validation:\n{detail}")


class CorpusValidationError(PipelineError):
    def __init__(self, subject: str, errors: Iterable[str]):
        self.subject = subject
        self.errors = tuple(errors)
        detail = "\n".join(f"  - {error}" for error in self.errors)
        super().__init__(f"{subject} failed corpus validation:\n{detail}")
