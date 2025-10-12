"""
Application Insights telemetry service.
"""

import logging
from typing import Dict, Optional, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class TelemetryService:
    """Service for Application Insights telemetry."""
    
    def __init__(self, connection_string: Optional[str] = None):
        """
        Initialize telemetry service.
        
        Args:
            connection_string: Application Insights connection string
        """
        self.connection_string = connection_string
        self.enabled = connection_string is not None
        
        if self.enabled:
            try:
                from applicationinsights import TelemetryClient
                self.client = TelemetryClient(connection_string)
                logger.info("Application Insights telemetry enabled")
            except ImportError:
                logger.warning("applicationinsights package not found, telemetry disabled")
                self.enabled = False
                self.client = None
        else:
            self.client = None
            logger.info("Telemetry disabled (no connection string)")
    
    def track_event(
        self,
        name: str,
        properties: Optional[Dict[str, Any]] = None,
        measurements: Optional[Dict[str, float]] = None,
    ):
        """Track a custom event."""
        if not self.enabled or not self.client:
            return
        
        try:
            self.client.track_event(name, properties, measurements)
            self.client.flush()
        except Exception as e:
            logger.error(f"Failed to track event: {str(e)}")
    
    def track_metric(
        self,
        name: str,
        value: float,
        properties: Optional[Dict[str, str]] = None,
    ):
        """Track a custom metric."""
        if not self.enabled or not self.client:
            return
        
        try:
            self.client.track_metric(name, value, properties=properties)
            self.client.flush()
        except Exception as e:
            logger.error(f"Failed to track metric: {str(e)}")
    
    def track_exception(
        self,
        exception: Exception,
        properties: Optional[Dict[str, str]] = None,
    ):
        """Track an exception."""
        if not self.enabled or not self.client:
            return
        
        try:
            self.client.track_exception(
                type(exception),
                exception,
                exception.__traceback__,
                properties=properties,
            )
            self.client.flush()
        except Exception as e:
            logger.error(f"Failed to track exception: {str(e)}")
    
    def track_dependency(
        self,
        name: str,
        data: str,
        type_name: str,
        target: Optional[str] = None,
        duration: Optional[float] = None,
        success: bool = True,
        result_code: Optional[str] = None,
        properties: Optional[Dict[str, str]] = None,
    ):
        """Track a dependency call."""
        if not self.enabled or not self.client:
            return
        
        try:
            self.client.track_dependency(
                name=name,
                data=data,
                type=type_name,
                target=target,
                duration=duration,
                success=success,
                result_code=result_code,
                properties=properties,
            )
            self.client.flush()
        except Exception as e:
            logger.error(f"Failed to track dependency: {str(e)}")
    
    def track_request(
        self,
        name: str,
        url: str,
        success: bool,
        duration: float,
        response_code: int,
        http_method: str = "GET",
        properties: Optional[Dict[str, str]] = None,
    ):
        """Track an HTTP request."""
        if not self.enabled or not self.client:
            return
        
        try:
            self.client.track_request(
                name=name,
                url=url,
                success=success,
                start_time=datetime.utcnow(),
                duration=duration,
                response_code=response_code,
                http_method=http_method,
                properties=properties,
            )
            self.client.flush()
        except Exception as e:
            logger.error(f"Failed to track request: {str(e)}")

