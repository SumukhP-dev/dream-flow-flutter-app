"""
Enhanced monitoring and alerting utilities.
Extends Sentry integration with custom alerts and health checks.
"""

import logging
import sentry_sdk
from typing import Optional, Dict, Any
from datetime import datetime

logger = logging.getLogger("dream_flow")


class MonitoringService:
    """Service for enhanced monitoring and alerting."""

    @staticmethod
    def capture_error(
        error: Exception,
        context: Optional[Dict[str, Any]] = None,
        level: str = "error",
    ) -> None:
        """
        Capture error with enhanced context.

        Args:
            error: Exception to capture
            context: Additional context dictionary
            level: Error level (error, warning, info)
        """
        with sentry_sdk.push_scope() as scope:
            if context:
                for key, value in context.items():
                    scope.set_context(key, value)
            
            scope.level = level
            sentry_sdk.capture_exception(error)

    @staticmethod
    def capture_message(
        message: str,
        context: Optional[Dict[str, Any]] = None,
        level: str = "info",
    ) -> None:
        """
        Capture message with context.

        Args:
            message: Message to capture
            context: Additional context dictionary
            level: Message level (error, warning, info)
        """
        with sentry_sdk.push_scope() as scope:
            if context:
                for key, value in context.items():
                    scope.set_context(key, value)
            
            scope.level = level
            sentry_sdk.capture_message(message, level=level)

    @staticmethod
    def track_performance(
        operation: str,
        duration_ms: float,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Track performance metrics.

        Args:
            operation: Operation name
            duration_ms: Duration in milliseconds
            metadata: Additional metadata
        """
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("operation", operation)
            scope.set_measurement("duration", duration_ms, unit="millisecond")
            
            if metadata:
                for key, value in metadata.items():
                    scope.set_context(key, value)
            
            # Log slow operations as warnings
            if duration_ms > 5000:  # 5 seconds
                scope.level = "warning"
                sentry_sdk.capture_message(
                    f"Slow operation: {operation} took {duration_ms}ms",
                    level="warning",
                )

    @staticmethod
    def track_user_action(
        action: str,
        user_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Track user actions for analytics.

        Args:
            action: Action name
            user_id: User ID (optional)
            metadata: Additional metadata
        """
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("action", action)
            
            if user_id:
                scope.set_user({"id": user_id})
            
            if metadata:
                for key, value in metadata.items():
                    scope.set_context(key, value)
            
            # Use breadcrumbs for user actions (non-critical)
            sentry_sdk.add_breadcrumb(
                message=action,
                category="user_action",
                level="info",
                data=metadata or {},
            )

    @staticmethod
    def create_health_check() -> Dict[str, Any]:
        """
        Create comprehensive health check data.

        Returns:
            Dictionary with health check information
        """
        import psutil
        import os
        
        try:
            process = psutil.Process(os.getpid())
            memory_info = process.memory_info()
            
            return {
                "status": "healthy",
                "timestamp": datetime.utcnow().isoformat(),
                "memory": {
                    "rss_mb": round(memory_info.rss / 1024 / 1024, 2),
                    "vms_mb": round(memory_info.vms / 1024 / 1024, 2),
                },
                "cpu": {
                    "percent": round(process.cpu_percent(interval=0.1), 2),
                },
            }
        except Exception as e:
            logger.error(f"Failed to create health check: {e}")
            return {
                "status": "degraded",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e),
            }

