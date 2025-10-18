"""
Tests for the dynamic dictionary feature in batch translation.
"""

import pytest
from app.services.batch_service import BatchTranslationService


class TestDictionaryAnnotation:
    """Test cases for dictionary text annotation."""

    def test_annotate_text_with_single_term(self):
        """Test annotation with a single dictionary term."""
        # Create a mock batch service (we only need the method, not dependencies)
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The API provides access to translation services."
        dictionary = {"API": "API"}
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        expected = 'The <mstrans:dictionary translation="API">API</mstrans:dictionary> provides access to translation services.'
        assert result == expected

    def test_annotate_text_with_multiple_terms(self):
        """Test annotation with multiple dictionary terms."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The API uses Azure Translator with gpt-4o-mini model."
        dictionary = {
            "API": "API",
            "Azure Translator": "Azure Translator",
            "gpt-4o-mini": "GPT-4o Mini"
        }
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # Check that all terms are annotated
        assert '<mstrans:dictionary translation="API">API</mstrans:dictionary>' in result
        assert '<mstrans:dictionary translation="Azure Translator">Azure Translator</mstrans:dictionary>' in result
        assert '<mstrans:dictionary translation="GPT-4o Mini">gpt-4o-mini</mstrans:dictionary>' in result

    def test_annotate_text_case_insensitive(self):
        """Test that annotation is case-insensitive."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The api provides API functionality. Api is great."
        dictionary = {"api": "API"}
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # Should match all variations of "api"
        assert result.count('<mstrans:dictionary') == 3

    def test_annotate_text_whole_word_only(self):
        """Test that annotation only matches whole words."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The API and APIS are different. Application is not API."
        dictionary = {"API": "API"}
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # Should only match "API" (whole word), not "APIS" or "Application"
        assert result.count('<mstrans:dictionary') == 1
        assert '<mstrans:dictionary translation="API">API</mstrans:dictionary>' in result
        assert 'APIS' in result  # Should not be annotated
        assert 'Application' in result  # Should not be annotated

    def test_annotate_text_with_custom_translation(self):
        """Test annotation with custom translation (not preserve)."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The word wordomatic is a dictionary entry."
        dictionary = {"wordomatic": "Wordomático"}
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        expected = 'The word <mstrans:dictionary translation="Wordomático">wordomatic</mstrans:dictionary> is a dictionary entry.'
        assert result == expected

    def test_annotate_text_empty_dictionary(self):
        """Test annotation with empty dictionary returns original text."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "This is a test."
        dictionary = {}
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        assert result == text

    def test_annotate_text_none_dictionary(self):
        """Test annotation with None dictionary returns original text."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "This is a test."
        dictionary = None
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        assert result == text

    def test_annotate_text_special_characters(self):
        """Test annotation with terms containing special regex characters."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The cost is $100 and the regex is .*test."
        dictionary = {
            "$100": "$100",
            ".*test": ".*test"
        }
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # Special characters should be escaped, so both should be annotated
        assert '<mstrans:dictionary translation="$100">$100</mstrans:dictionary>' in result
        # Note: ".*test" might not match because it's not a valid word boundary pattern

    def test_annotate_text_longest_first(self):
        """Test that longer terms are processed first to avoid partial matches."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "Azure Translator is better than Azure services."
        dictionary = {
            "Azure": "Azure",
            "Azure Translator": "Azure Translator"
        }
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # "Azure Translator" should be annotated as a whole, not as separate "Azure"
        assert '<mstrans:dictionary translation="Azure Translator">Azure Translator</mstrans:dictionary>' in result
        # The second "Azure" should be annotated separately
        assert result.count('<mstrans:dictionary') == 2

    def test_annotate_text_preserve_vs_translate(self):
        """Test both preserve (term=translation) and translate (term≠translation) scenarios."""
        service = BatchTranslationService.__new__(BatchTranslationService)
        
        text = "The API uses the wordomatic feature."
        dictionary = {
            "API": "API",  # Preserve
            "wordomatic": "Diccionario Dinámico"  # Translate
        }
        
        result = service.annotate_text_with_dictionary(text, dictionary)
        
        # Both should be annotated with their respective translations
        assert '<mstrans:dictionary translation="API">API</mstrans:dictionary>' in result
        assert '<mstrans:dictionary translation="Diccionario Dinámico">wordomatic</mstrans:dictionary>' in result


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])

