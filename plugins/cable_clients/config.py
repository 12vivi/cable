"""Cable Web client plugin configuration."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class WebClientConfig(BaseModel):
    """Web Chat switch and host-owned socket projection."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    enabled: bool = True
    socket_path: str = ""

    @field_validator("socket_path")
    @classmethod
    def validate_socket_path(cls, value: str) -> str:
        value = value.strip()
        if "\x00" in value:
            raise ValueError("web.socket_path 不能包含 NUL")
        return value


class CableClientsConfig(BaseModel):
    """The only config model consumed by the ordinary cable_clients plugin."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    enabled: bool = True
    web: WebClientConfig = Field(default_factory=WebClientConfig)

    @model_validator(mode="after")
    def require_enabled_client(self) -> CableClientsConfig:
        if self.enabled and not self.web.enabled:
            raise ValueError("cable_clients 启用时需要启用 Web")
        return self


Config = CableClientsConfig

__all__ = [
    "CableClientsConfig",
    "Config",
    "WebClientConfig",
]
