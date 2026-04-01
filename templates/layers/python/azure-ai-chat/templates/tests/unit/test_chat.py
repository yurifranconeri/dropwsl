"""Unit tests for chat package (responses, completions, _common, models)."""

import os
from unittest.mock import MagicMock, patch

import pytest
from pydantic import ValidationError

import chat._common as common_mod
import chat.completions as completions_mod
import chat.responses as responses_mod
from chat.models import ChatRequest, ChatResponse


# ---------------------------------------------------------------------------
# models.py — Pydantic models
# ---------------------------------------------------------------------------


class TestChatRequest:
    """Tests for ChatRequest model."""

    def test_minimal_request(self) -> None:
        req = ChatRequest(message="hello")
        assert req.message == "hello"
        assert req.model is None
        assert req.previous_response_id is None
        assert req.instructions is None

    def test_full_request(self) -> None:
        req = ChatRequest(
            message="hello",
            model="gpt-4.1",
            previous_response_id="resp_abc",
            instructions="Be helpful",
        )
        assert req.model == "gpt-4.1"
        assert req.previous_response_id == "resp_abc"

    def test_optional_sampling_params(self) -> None:
        req = ChatRequest(
            message="hello",
            temperature=0.5,
            top_p=0.9,
            max_output_tokens=1024,
        )
        assert req.temperature == 0.5
        assert req.top_p == 0.9
        assert req.max_output_tokens == 1024

    def test_optional_behavior_params(self) -> None:
        req = ChatRequest(
            message="hello",
            truncation="auto",
            store=False,
            reasoning_effort="high",
        )
        assert req.truncation == "auto"
        assert req.store is False
        assert req.reasoning_effort == "high"

    def test_sampling_defaults_are_none(self) -> None:
        req = ChatRequest(message="hello")
        assert req.temperature is None
        assert req.top_p is None
        assert req.max_output_tokens is None
        assert req.truncation is None
        assert req.store is None
        assert req.reasoning_effort is None

    def test_temperature_validation(self) -> None:
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", temperature=3.0)
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", temperature=-0.1)

    def test_top_p_validation(self) -> None:
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", top_p=1.5)
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", top_p=-0.1)

    def test_max_output_tokens_validation(self) -> None:
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", max_output_tokens=0)

    def test_missing_message_raises(self) -> None:
        with pytest.raises(ValidationError):
            ChatRequest()

    def test_api_mode_default_is_responses(self) -> None:
        req = ChatRequest(message="hello")
        assert req.api_mode == "responses"

    def test_api_mode_completions_valid(self) -> None:
        req = ChatRequest(message="hello", api_mode="completions")
        assert req.api_mode == "completions"

    def test_api_mode_invalid_raises(self) -> None:
        with pytest.raises(ValidationError):
            ChatRequest(message="hello", api_mode="invalid")

    def test_history_field_optional(self) -> None:
        req = ChatRequest(message="hello")
        assert req.history is None

    def test_history_with_messages(self) -> None:
        history = [
            {"role": "user", "content": "first"},
            {"role": "assistant", "content": "reply"},
        ]
        req = ChatRequest(message="hello", history=history)
        assert req.history == history
        assert len(req.history) == 2


class TestChatResponse:
    """Tests for ChatResponse model."""

    def test_valid_response(self) -> None:
        resp = ChatResponse(
            response_id="resp_1",
            model="gpt-4.1",
            text="Hi there!",
            usage={"input_tokens": 5, "output_tokens": 3, "total_tokens": 8},
        )
        assert resp.response_id == "resp_1"
        assert resp.text == "Hi there!"
        assert resp.usage_details == {}

    def test_response_with_usage_details(self) -> None:
        resp = ChatResponse(
            response_id="resp_1",
            model="gpt-4.1",
            text="Hi",
            usage={"input_tokens": 5, "output_tokens": 3, "total_tokens": 8},
            usage_details={"reasoning_tokens": 10, "cached_tokens": 3},
        )
        assert resp.usage_details["reasoning_tokens"] == 10
        assert resp.usage_details["cached_tokens"] == 3


# ---------------------------------------------------------------------------
# _common.py — resolve_model
# ---------------------------------------------------------------------------


class TestResolveModel:
    """Tests for resolve_model()."""

    def test_explicit_model_wins(self) -> None:
        result = common_mod.resolve_model("gpt-4.1")
        assert result == "gpt-4.1"

    def test_env_var_fallback(self) -> None:
        with patch.dict(os.environ, {"AZURE_AI_CHAT_MODEL": "gpt-4o"}):
            result = common_mod.resolve_model(None)
            assert result == "gpt-4o"

    def test_explicit_overrides_env(self) -> None:
        with patch.dict(os.environ, {"AZURE_AI_CHAT_MODEL": "gpt-4o"}):
            result = common_mod.resolve_model("gpt-4.1")
            assert result == "gpt-4.1"

    def test_no_model_no_env_raises(self) -> None:
        with patch.dict(os.environ, {}, clear=True), pytest.raises(ValueError, match="AZURE_AI_CHAT_MODEL"):
            common_mod.resolve_model(None)


# ---------------------------------------------------------------------------
# _common.py — chat_health
# ---------------------------------------------------------------------------


class TestChatHealth:
    """Tests for chat_health()."""

    def test_true_when_env_set(self) -> None:
        with patch.dict(os.environ, {"AZURE_AI_CHAT_MODEL": "gpt-4.1"}):
            assert common_mod.chat_health() is True

    def test_false_when_env_empty(self) -> None:
        with patch.dict(os.environ, {"AZURE_AI_CHAT_MODEL": ""}):
            assert common_mod.chat_health() is False

    def test_false_when_env_unset(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            assert common_mod.chat_health() is False


# ---------------------------------------------------------------------------
# _common.py — usage_to_dict
# ---------------------------------------------------------------------------


class TestUsageToDict:
    """Tests for usage_to_dict()."""

    def test_none_returns_empty(self) -> None:
        assert common_mod.usage_to_dict(None) == {}

    def test_responses_api_usage(self) -> None:
        usage = MagicMock()
        usage.input_tokens = 10
        usage.output_tokens = 5
        usage.total_tokens = 15
        result = common_mod.usage_to_dict(usage)
        assert result == {"input_tokens": 10, "output_tokens": 5, "total_tokens": 15}

    def test_completions_api_usage(self) -> None:
        """Chat Completions uses prompt_tokens / completion_tokens."""
        usage = MagicMock(spec=[])
        usage.prompt_tokens = 12
        usage.completion_tokens = 7
        usage.total_tokens = 19
        result = common_mod.usage_to_dict(usage)
        assert result == {"input_tokens": 12, "output_tokens": 7, "total_tokens": 19}

    def test_missing_attrs_default_zero(self) -> None:
        usage = object()
        result = common_mod.usage_to_dict(usage)
        assert result == {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}


# ---------------------------------------------------------------------------
# _common.py — usage_details_to_dict
# ---------------------------------------------------------------------------


class TestUsageDetailsToDict:
    """Tests for usage_details_to_dict()."""

    def test_none_returns_zeros(self) -> None:
        result = common_mod.usage_details_to_dict(None)
        assert result == {"reasoning_tokens": 0, "cached_tokens": 0}

    def test_with_reasoning_tokens(self) -> None:
        usage = MagicMock()
        output_details = MagicMock()
        output_details.reasoning_tokens = 42
        usage.output_tokens_details = output_details
        usage.input_tokens_details = None
        result = common_mod.usage_details_to_dict(usage)
        assert result["reasoning_tokens"] == 42
        assert result["cached_tokens"] == 0

    def test_with_cached_tokens(self) -> None:
        usage = MagicMock()
        usage.output_tokens_details = None
        input_details = MagicMock()
        input_details.cached_tokens = 100
        usage.input_tokens_details = input_details
        result = common_mod.usage_details_to_dict(usage)
        assert result["reasoning_tokens"] == 0
        assert result["cached_tokens"] == 100

    def test_with_both_details(self) -> None:
        usage = MagicMock()
        output_details = MagicMock()
        output_details.reasoning_tokens = 50
        usage.output_tokens_details = output_details
        input_details = MagicMock()
        input_details.cached_tokens = 200
        usage.input_tokens_details = input_details
        result = common_mod.usage_details_to_dict(usage)
        assert result == {"reasoning_tokens": 50, "cached_tokens": 200}

    def test_missing_sub_attrs_default_zero(self) -> None:
        """Models that report details objects but without specific fields."""
        usage = MagicMock()
        usage.output_tokens_details = object()
        usage.input_tokens_details = object()
        result = common_mod.usage_details_to_dict(usage)
        assert result == {"reasoning_tokens": 0, "cached_tokens": 0}


# ---------------------------------------------------------------------------
# responses.py — send_message (Responses API)
# ---------------------------------------------------------------------------


class TestSendMessage:
    """Tests for responses.send_message()."""

    def _mock_response(self) -> MagicMock:
        resp = MagicMock()
        resp.id = "resp_test_123"
        resp.model = "gpt-4.1-2025-04-14"
        resp.output_text = "Hello! How can I help?"
        usage = MagicMock()
        usage.input_tokens = 10
        usage.output_tokens = 8
        usage.total_tokens = 18
        resp.usage = usage
        return resp

    def test_basic_message(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            result = responses_mod.send_message("hi", model="gpt-4.1")
            assert result["response_id"] == "resp_test_123"
            assert result["text"] == "Hello! How can I help?"
            assert result["usage"]["total_tokens"] == 18
            assert "usage_details" in result
            mock_client.responses.create.assert_called_once_with(
                model="gpt-4.1", input="hi"
            )

    def test_with_temperature_and_top_p(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message(
                "hi", model="gpt-4.1", temperature=0.7, top_p=0.9
            )
            call_kwargs = mock_client.responses.create.call_args
            assert call_kwargs.kwargs.get("temperature") == 0.7 or \
                   (len(call_kwargs) > 1 and call_kwargs[1].get("temperature") == 0.7)

    def test_with_max_output_tokens(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message(
                "hi", model="gpt-4.1", max_output_tokens=512
            )
            call_kwargs = mock_client.responses.create.call_args
            assert call_kwargs.kwargs.get("max_output_tokens") == 512 or \
                   (len(call_kwargs) > 1 and call_kwargs[1].get("max_output_tokens") == 512)

    def test_reasoning_effort_becomes_dict(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message(
                "hi", model="o3", reasoning_effort="high"
            )
            call_kwargs = mock_client.responses.create.call_args
            reasoning = call_kwargs.kwargs.get("reasoning") or \
                (call_kwargs[1].get("reasoning") if len(call_kwargs) > 1 else None)
            assert reasoning == {"effort": "high"}

    def test_none_params_not_forwarded(self) -> None:
        """Parameters left as None must not appear in kwargs."""
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message("hi", model="gpt-4.1")
            call_kwargs = mock_client.responses.create.call_args
            forwarded = call_kwargs.kwargs if call_kwargs.kwargs else call_kwargs[1] if len(call_kwargs) > 1 else {}
            for key in ("temperature", "top_p", "max_output_tokens", "truncation", "store", "reasoning"):
                assert key not in forwarded, f"{key} should not be forwarded when None"

    def test_with_previous_response_id(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message(
                "follow up",
                model="gpt-4.1",
                previous_response_id="resp_prev",
            )
            call_kwargs = mock_client.responses.create.call_args
            assert call_kwargs.kwargs.get("previous_response_id") == "resp_prev" or \
                   (len(call_kwargs) > 1 and call_kwargs[1].get("previous_response_id") == "resp_prev")

    def test_with_instructions(self) -> None:
        mock_client = MagicMock()
        mock_client.responses.create.return_value = self._mock_response()
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            responses_mod.send_message(
                "hi", model="gpt-4.1", instructions="Be concise"
            )
            call_kwargs = mock_client.responses.create.call_args
            assert "instructions" in str(call_kwargs)

    def test_output_text_none_returns_empty(self) -> None:
        mock_resp = self._mock_response()
        mock_resp.output_text = None
        mock_client = MagicMock()
        mock_client.responses.create.return_value = mock_resp
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            result = responses_mod.send_message("hi", model="gpt-4.1")
            assert result["text"] == ""

    def test_no_model_raises_without_env(self) -> None:
        with patch.dict(os.environ, {}, clear=True), pytest.raises(ValueError, match="AZURE_AI_CHAT_MODEL"):
            responses_mod.send_message("hi")


# ---------------------------------------------------------------------------
# responses.py — send_message_stream (Responses API)
# ---------------------------------------------------------------------------


class TestSendMessageStream:
    """Tests for responses.send_message_stream()."""

    def test_yields_created_delta_done(self) -> None:
        created_event = MagicMock()
        created_event.type = "response.created"
        created_event.response.id = "resp_stream_1"

        delta_event = MagicMock()
        delta_event.type = "response.output_text.delta"
        delta_event.delta = "Hello"

        done_event = MagicMock()
        done_event.type = "response.completed"
        done_event.response.id = "resp_stream_1"
        done_event.response.model = "gpt-4.1"
        usage = MagicMock()
        usage.input_tokens = 5
        usage.output_tokens = 3
        usage.total_tokens = 8
        done_event.response.usage = usage

        mock_client = MagicMock()
        mock_client.responses.create.return_value = iter(
            [created_event, delta_event, done_event]
        )
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            events = list(
                responses_mod.send_message_stream("hi", model="gpt-4.1")
            )
            assert len(events) == 3
            assert events[0]["type"] == "created"
            assert events[0]["response_id"] == "resp_stream_1"
            assert events[1]["type"] == "delta"
            assert events[1]["text"] == "Hello"
            assert events[2]["type"] == "done"
            assert events[2]["usage"]["total_tokens"] == 8

    def test_ignores_unknown_event_types(self) -> None:
        unknown_event = MagicMock()
        unknown_event.type = "response.something_else"

        mock_client = MagicMock()
        mock_client.responses.create.return_value = iter([unknown_event])
        with patch.object(responses_mod, "get_openai_client", return_value=mock_client):
            events = list(
                responses_mod.send_message_stream("hi", model="gpt-4.1")
            )
            assert events == []


# ---------------------------------------------------------------------------
# responses.py — _apply_optional_kwargs
# ---------------------------------------------------------------------------


class TestApplyOptionalKwargs:
    """Tests for responses._apply_optional_kwargs()."""

    def test_none_values_not_added(self) -> None:
        kwargs: dict = {"model": "gpt-4.1", "input": "hi"}
        responses_mod._apply_optional_kwargs(
            kwargs,
            temperature=None,
            top_p=None,
            max_output_tokens=None,
            truncation=None,
            store=None,
            reasoning_effort=None,
        )
        assert kwargs == {"model": "gpt-4.1", "input": "hi"}

    def test_all_values_added(self) -> None:
        kwargs: dict = {"model": "o3", "input": "hi"}
        responses_mod._apply_optional_kwargs(
            kwargs,
            temperature=0.5,
            top_p=0.8,
            max_output_tokens=1024,
            truncation="auto",
            store=False,
            reasoning_effort="high",
        )
        assert kwargs["temperature"] == 0.5
        assert kwargs["top_p"] == 0.8
        assert kwargs["max_output_tokens"] == 1024
        assert kwargs["truncation"] == "auto"
        assert kwargs["store"] is False
        assert kwargs["reasoning"] == {"effort": "high"}
        assert "reasoning_effort" not in kwargs

    def test_partial_values(self) -> None:
        kwargs: dict = {"model": "gpt-4.1", "input": "hi"}
        responses_mod._apply_optional_kwargs(
            kwargs,
            temperature=0.3,
            top_p=None,
            max_output_tokens=None,
            truncation=None,
            store=None,
            reasoning_effort=None,
        )
        assert kwargs == {"model": "gpt-4.1", "input": "hi", "temperature": 0.3}


# ---------------------------------------------------------------------------
# completions.py — send_message (Chat Completions API)
# ---------------------------------------------------------------------------


class TestSendMessageCompletions:
    """Tests for completions.send_message()."""

    def _mock_completions_response(self) -> MagicMock:
        resp = MagicMock()
        resp.id = "chatcmpl_test_456"
        resp.model = "deepseek-r1"
        choice = MagicMock()
        choice.message.content = "Hello from completions!"
        resp.choices = [choice]
        usage = MagicMock()
        usage.prompt_tokens = 10
        usage.completion_tokens = 8
        usage.total_tokens = 18
        resp.usage = usage
        return resp

    def test_basic_message(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            result = completions_mod.send_message("hi", model="deepseek-r1")
            assert result["response_id"] == "chatcmpl_test_456"
            assert result["text"] == "Hello from completions!"
            assert "usage_details" in result
            call_kwargs = mock_client.chat.completions.create.call_args
            assert call_kwargs.kwargs["messages"] == [{"role": "user", "content": "hi"}]

    def test_with_history(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        history = [
            {"role": "user", "content": "first"},
            {"role": "assistant", "content": "reply"},
        ]
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message("follow up", model="deepseek-r1", history=history)
            call_kwargs = mock_client.chat.completions.create.call_args
            messages = call_kwargs.kwargs["messages"]
            assert len(messages) == 3
            assert messages[0] == {"role": "user", "content": "first"}
            assert messages[1] == {"role": "assistant", "content": "reply"}
            assert messages[2] == {"role": "user", "content": "follow up"}

    def test_with_instructions_and_history(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        history = [{"role": "user", "content": "prev"}]
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message(
                "hi", model="deepseek-r1",
                instructions="Be concise", history=history,
            )
            call_kwargs = mock_client.chat.completions.create.call_args
            messages = call_kwargs.kwargs["messages"]
            assert messages[0] == {"role": "system", "content": "Be concise"}
            assert messages[1] == {"role": "user", "content": "prev"}
            assert messages[2] == {"role": "user", "content": "hi"}

    def test_with_temperature_and_top_p(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message(
                "hi", model="deepseek-r1", temperature=0.7, top_p=0.9
            )
            call_kwargs = mock_client.chat.completions.create.call_args
            assert call_kwargs.kwargs.get("temperature") == 0.7

    def test_max_output_tokens_mapped_to_max_completion_tokens(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message(
                "hi", model="deepseek-r1", max_output_tokens=512
            )
            call_kwargs = mock_client.chat.completions.create.call_args
            assert call_kwargs.kwargs.get("max_completion_tokens") == 512
            assert "max_output_tokens" not in call_kwargs.kwargs

    def test_reasoning_effort_is_top_level(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message(
                "hi", model="deepseek-r1", reasoning_effort="high"
            )
            call_kwargs = mock_client.chat.completions.create.call_args
            assert call_kwargs.kwargs.get("reasoning_effort") == "high"
            assert "reasoning" not in call_kwargs.kwargs

    def test_none_params_not_forwarded(self) -> None:
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = self._mock_completions_response()
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            completions_mod.send_message("hi", model="deepseek-r1")
            call_kwargs = mock_client.chat.completions.create.call_args
            forwarded = call_kwargs.kwargs
            for key in ("temperature", "top_p", "max_completion_tokens", "reasoning_effort"):
                assert key not in forwarded, f"{key} should not be forwarded when None"

    def test_no_model_raises_without_env(self) -> None:
        with patch.dict(os.environ, {}, clear=True), pytest.raises(ValueError, match="AZURE_AI_CHAT_MODEL"):
            completions_mod.send_message("hi")

    def test_empty_choices_returns_empty_text(self) -> None:
        mock_resp = self._mock_completions_response()
        mock_resp.choices = []
        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = mock_resp
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            result = completions_mod.send_message("hi", model="deepseek-r1")
            assert result["text"] == ""


# ---------------------------------------------------------------------------
# completions.py — send_message_stream (Chat Completions API)
# ---------------------------------------------------------------------------


class TestSendMessageCompletionsStream:
    """Tests for completions.send_message_stream()."""

    def test_yields_created_delta_done(self) -> None:
        # First chunk: has id, first delta
        chunk1 = MagicMock()
        chunk1.id = "chatcmpl_stream_1"
        chunk1.model = "deepseek-r1"
        chunk1.choices = [MagicMock()]
        chunk1.choices[0].delta.content = "Hello"
        chunk1.usage = None

        # Second chunk: more content
        chunk2 = MagicMock()
        chunk2.id = "chatcmpl_stream_1"
        chunk2.model = "deepseek-r1"
        chunk2.choices = [MagicMock()]
        chunk2.choices[0].delta.content = " world"
        chunk2.usage = None

        # Final chunk: usage
        chunk3 = MagicMock()
        chunk3.id = "chatcmpl_stream_1"
        chunk3.model = "deepseek-r1"
        chunk3.choices = []
        usage = MagicMock()
        usage.prompt_tokens = 5
        usage.completion_tokens = 3
        usage.total_tokens = 8
        chunk3.usage = usage

        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = iter(
            [chunk1, chunk2, chunk3]
        )
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            events = list(
                completions_mod.send_message_stream("hi", model="deepseek-r1")
            )
            types = [e["type"] for e in events]
            assert "created" in types
            assert "delta" in types
            assert "done" in types
            created = next(e for e in events if e["type"] == "created")
            assert created["response_id"] == "chatcmpl_stream_1"
            deltas = [e for e in events if e["type"] == "delta"]
            assert len(deltas) == 2
            assert deltas[0]["text"] == "Hello"
            assert deltas[1]["text"] == " world"

    def test_ignores_empty_deltas(self) -> None:
        chunk = MagicMock()
        chunk.id = "chatcmpl_1"
        chunk.model = "test"
        chunk.choices = [MagicMock()]
        chunk.choices[0].delta.content = None
        chunk.usage = None

        mock_client = MagicMock()
        mock_client.chat.completions.create.return_value = iter([chunk])
        with patch.object(completions_mod, "get_openai_client", return_value=mock_client):
            events = list(
                completions_mod.send_message_stream("hi", model="test")
            )
            delta_events = [e for e in events if e["type"] == "delta"]
            assert delta_events == []


# ---------------------------------------------------------------------------
# completions.py — _build_messages
# ---------------------------------------------------------------------------


class TestBuildMessages:
    """Tests for completions._build_messages()."""

    def test_message_only(self) -> None:
        result = completions_mod._build_messages("hello")
        assert result == [{"role": "user", "content": "hello"}]

    def test_with_instructions(self) -> None:
        result = completions_mod._build_messages("hello", instructions="Be brief")
        assert result == [
            {"role": "system", "content": "Be brief"},
            {"role": "user", "content": "hello"},
        ]

    def test_with_history(self) -> None:
        history = [
            {"role": "user", "content": "first"},
            {"role": "assistant", "content": "reply"},
        ]
        result = completions_mod._build_messages("follow up", history=history)
        assert len(result) == 3
        assert result[0] == {"role": "user", "content": "first"}
        assert result[1] == {"role": "assistant", "content": "reply"}
        assert result[2] == {"role": "user", "content": "follow up"}

    def test_with_instructions_and_history(self) -> None:
        history = [{"role": "user", "content": "prev"}]
        result = completions_mod._build_messages(
            "hello", instructions="Be brief", history=history
        )
        assert result[0] == {"role": "system", "content": "Be brief"}
        assert result[1] == {"role": "user", "content": "prev"}
        assert result[2] == {"role": "user", "content": "hello"}

    def test_empty_history_ignored(self) -> None:
        result = completions_mod._build_messages("hello", history=[])
        assert result == [{"role": "user", "content": "hello"}]

    def test_none_history_ignored(self) -> None:
        result = completions_mod._build_messages("hello", history=None)
        assert result == [{"role": "user", "content": "hello"}]


# ---------------------------------------------------------------------------
# completions.py — _apply_completions_kwargs
# ---------------------------------------------------------------------------


class TestApplyCompletionsKwargs:
    """Tests for completions._apply_completions_kwargs()."""

    def test_none_values_not_added(self) -> None:
        kwargs: dict = {"model": "deepseek-r1", "messages": []}
        completions_mod._apply_completions_kwargs(
            kwargs,
            temperature=None,
            top_p=None,
            max_output_tokens=None,
            reasoning_effort=None,
        )
        assert kwargs == {"model": "deepseek-r1", "messages": []}

    def test_all_values_added(self) -> None:
        kwargs: dict = {"model": "deepseek-r1", "messages": []}
        completions_mod._apply_completions_kwargs(
            kwargs,
            temperature=0.5,
            top_p=0.8,
            max_output_tokens=1024,
            reasoning_effort="high",
        )
        assert kwargs["temperature"] == 0.5
        assert kwargs["top_p"] == 0.8
        assert kwargs["max_completion_tokens"] == 1024
        assert kwargs["reasoning_effort"] == "high"
        assert "max_output_tokens" not in kwargs
        assert "reasoning" not in kwargs

    def test_reasoning_effort_top_level_not_nested(self) -> None:
        kwargs: dict = {"model": "o3", "messages": []}
        completions_mod._apply_completions_kwargs(
            kwargs,
            temperature=None,
            top_p=None,
            max_output_tokens=None,
            reasoning_effort="medium",
        )
        assert kwargs["reasoning_effort"] == "medium"
        assert "reasoning" not in kwargs

    def test_no_truncation_no_store(self) -> None:
        """Chat Completions API does not support truncation or store."""
        kwargs: dict = {"model": "deepseek-r1", "messages": []}
        completions_mod._apply_completions_kwargs(
            kwargs,
            temperature=None,
            top_p=None,
            max_output_tokens=None,
            reasoning_effort=None,
        )
        assert "truncation" not in kwargs
        assert "store" not in kwargs

    def test_partial_values(self) -> None:
        kwargs: dict = {"model": "deepseek-r1", "messages": []}
        completions_mod._apply_completions_kwargs(
            kwargs,
            temperature=0.3,
            top_p=None,
            max_output_tokens=None,
            reasoning_effort=None,
        )
        assert kwargs == {"model": "deepseek-r1", "messages": [], "temperature": 0.3}
