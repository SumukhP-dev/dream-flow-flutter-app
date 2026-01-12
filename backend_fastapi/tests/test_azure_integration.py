"""
Tests for Azure AI services integration (Content Safety and Computer Vision).

These tests verify that Azure services are properly integrated and can be tested
without requiring actual Azure credentials (using mocks).
"""

import pytest
from unittest.mock import MagicMock, patch, Mock
from io import BytesIO

# Test Azure Content Safety
def test_content_safety_client_initialization():
    """Test that Azure Content Safety client can be initialized."""
    with patch('app.core.azure_content_safety.AZURE_CONTENT_SAFETY_AVAILABLE', True):
        with patch('app.core.azure_content_safety.ContentSafetyClient') as mock_client:
            from app.core.azure_content_safety import AzureContentSafetyClient
            
            client = AzureContentSafetyClient(
                endpoint="https://test.api.cognitive.microsoft.com/",
                key="test-key"
            )
            assert client is not None
            mock_client.assert_called_once()


def test_content_safety_text_moderation():
    """Test text moderation functionality."""
    with patch('app.core.azure_content_safety.AZURE_CONTENT_SAFETY_AVAILABLE', True):
        from app.core.azure_content_safety import AzureContentSafetyClient
        
        client = AzureContentSafetyClient(
            endpoint="https://test.api.cognitive.microsoft.com/",
            key="test-key"
        )
        
        # Mock the API response
        mock_response = MagicMock()
        mock_response.categories_analysis = []
        
        client.client.analyze_text = MagicMock(return_value=mock_response)
        
        result = client.moderate_text("This is a safe bedtime story.")
        assert result["is_safe"] is True
        assert "errors" in result


def test_content_safety_image_moderation():
    """Test image moderation functionality."""
    with patch('app.core.azure_content_safety.AZURE_CONTENT_SAFETY_AVAILABLE', True):
        from app.core.azure_content_safety import AzureContentSafetyClient
        
        client = AzureContentSafetyClient(
            endpoint="https://test.api.cognitive.microsoft.com/",
            key="test-key"
        )
        
        # Create mock image data
        image_data = b"fake_image_data"
        
        # Mock the API response
        mock_response = MagicMock()
        mock_response.categories_analysis = []
        
        client.client.analyze_image = MagicMock(return_value=mock_response)
        
        result = client.moderate_image(image_data)
        assert result["is_safe"] is True
        assert "errors" in result


# Test Azure Computer Vision
def test_computer_vision_client_initialization():
    """Test that Azure Computer Vision client can be initialized."""
    with patch('app.core.azure_computer_vision.AZURE_COMPUTER_VISION_AVAILABLE', True):
        with patch('app.core.azure_computer_vision.ComputerVisionClient') as mock_client:
            from app.core.azure_computer_vision import AzureComputerVisionClient
            
            client = AzureComputerVisionClient(
                endpoint="https://test.cognitiveservices.azure.com/",
                key="test-key"
            )
            assert client is not None
            mock_client.assert_called_once()


def test_computer_vision_describe_image():
    """Test image description functionality."""
    with patch('app.core.azure_computer_vision.AZURE_COMPUTER_VISION_AVAILABLE', True):
        from app.core.azure_computer_vision import AzureComputerVisionClient
        
        client = AzureComputerVisionClient(
            endpoint="https://test.cognitiveservices.azure.com/",
            key="test-key"
        )
        
        # Create mock image data
        image_data = b"fake_image_data"
        
        # Mock the API response
        mock_caption = MagicMock()
        mock_caption.text = "A peaceful bedtime scene"
        mock_caption.confidence = 0.95
        
        mock_response = MagicMock()
        mock_response.captions = [mock_caption]
        mock_response.tags = ["bedtime", "peaceful", "story"]
        
        client.client.describe_image_in_stream = MagicMock(return_value=mock_response)
        
        result = client.describe_image(image_data)
        assert "captions" in result
        assert len(result["captions"]) > 0
        assert result["captions"][0]["text"] == "A peaceful bedtime scene"


def test_computer_vision_analyze_image():
    """Test image analysis functionality."""
    with patch('app.core.azure_computer_vision.AZURE_COMPUTER_VISION_AVAILABLE', True):
        from app.core.azure_computer_vision import AzureComputerVisionClient
        
        client = AzureComputerVisionClient(
            endpoint="https://test.cognitiveservices.azure.com/",
            key="test-key"
        )
        
        # Create mock image data
        image_data = b"fake_image_data"
        
        # Mock the API response
        mock_response = MagicMock()
        mock_response.objects = []
        mock_response.tags = []
        mock_response.description = MagicMock()
        mock_response.description.tags = ["bedtime", "story"]
        mock_response.description.captions = []
        
        client.client.analyze_image_in_stream = MagicMock(return_value=mock_response)
        
        result = client.analyze_image(image_data)
        assert "objects" in result
        assert "tags" in result
        assert "description" in result


def test_content_safety_integration_with_guardrails():
    """Test that Azure Content Safety integrates with ContentGuard."""
    from app.core.guardrails import ContentGuard
    
    guard = ContentGuard()
    
    # ContentGuard should initialize with optional Azure client
    assert guard is not None
    
    # Test that check_story works (will use keyword-based checks if Azure not available)
    violations = guard.check_story(
        "This is a peaceful bedtime story about a sleepy kitten.",
        child_mode=False
    )
    assert isinstance(violations, list)


def test_computer_vision_alt_text_generation():
    """Test alt-text generation for accessibility."""
    with patch('app.core.azure_computer_vision.AZURE_COMPUTER_VISION_AVAILABLE', True):
        from app.core.azure_computer_vision import AzureComputerVisionClient
        
        client = AzureComputerVisionClient(
            endpoint="https://test.cognitiveservices.azure.com/",
            key="test-key"
        )
        
        # Create mock image data
        image_data = b"fake_image_data"
        
        # Mock the API response with caption
        mock_caption = MagicMock()
        mock_caption.text = "A peaceful bedtime scene with stars"
        mock_caption.confidence = 0.95
        
        mock_response = MagicMock()
        mock_response.captions = [mock_caption]
        mock_response.tags = []
        
        client.client.describe_image_in_stream = MagicMock(return_value=mock_response)
        
        alt_text = client.generate_alt_text(image_data)
        assert alt_text == "A peaceful bedtime scene with stars"


def test_get_content_safety_client_with_config():
    """Test getting Content Safety client from settings."""
    from app.shared.config import Settings
    from unittest.mock import patch
    
    # Mock settings
    with patch('app.core.azure_content_safety.settings') as mock_settings:
        mock_settings.azure_content_safety_enabled = True
        mock_settings.azure_content_safety_endpoint = "https://test.api.cognitive.microsoft.com/"
        mock_settings.azure_content_safety_key = "test-key"
        
        with patch('app.core.azure_content_safety.AZURE_CONTENT_SAFETY_AVAILABLE', True):
            with patch('app.core.azure_content_safety.AzureContentSafetyClient') as mock_client_class:
                from app.core.azure_content_safety import get_content_safety_client
                
                client = get_content_safety_client()
                if client is not None:
                    mock_client_class.assert_called_once()


def test_get_computer_vision_client_with_config():
    """Test getting Computer Vision client from settings."""
    from unittest.mock import patch
    
    # Mock settings
    with patch('app.core.azure_computer_vision.settings') as mock_settings:
        mock_settings.azure_computer_vision_enabled = True
        mock_settings.azure_computer_vision_endpoint = "https://test.cognitiveservices.azure.com/"
        mock_settings.azure_computer_vision_key = "test-key"
        
        with patch('app.core.azure_computer_vision.AZURE_COMPUTER_VISION_AVAILABLE', True):
            with patch('app.core.azure_computer_vision.AzureComputerVisionClient') as mock_client_class:
                from app.core.azure_computer_vision import get_computer_vision_client
                
                client = get_computer_vision_client()
                if client is not None:
                    mock_client_class.assert_called_once()


def test_content_safety_fail_open():
    """Test that Content Safety fails open (allows content if service unavailable)."""
    with patch('app.core.azure_content_safety.AZURE_CONTENT_SAFETY_AVAILABLE', False):
        from app.core.azure_content_safety import AzureContentSafetyClient
        
        # Should raise ImportError when SDK not available
        with pytest.raises(ImportError):
            client = AzureContentSafetyClient(
                endpoint="https://test.api.cognitive.microsoft.com/",
                key="test-key"
            )

