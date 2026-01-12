"""
Redis caching service for Klaviyo profile data.

This module provides a caching layer to reduce Klaviyo API calls,
respect rate limits, and improve response times for frequently accessed data.
"""

import json
import logging
from datetime import datetime, timedelta
from typing import Any, Optional
from uuid import UUID

try:
    import redis.asyncio as redis
except ImportError:
    redis = None

logger = logging.getLogger("dream_flow")


class KlaviyoCacheService:
    """
    Redis-based caching service for Klaviyo data.
    
    This service caches profile metrics, event data, and other frequently
    accessed Klaviyo information to reduce API calls and improve performance.
    """

    def __init__(
        self,
        redis_url: str = "redis://localhost:6379",
        default_ttl: int = 300,  # 5 minutes
    ):
        """
        Initialize Redis cache service.
        
        Args:
            redis_url: Redis connection URL
            default_ttl: Default TTL for cached data in seconds
        """
        self.redis_url = redis_url
        self.default_ttl = default_ttl
        self.redis_client: Optional[redis.Redis] = None
        self.enabled = redis is not None

        if not self.enabled:
            logger.warning("Redis not available. Install with: pip install redis[hiredis]")

    async def connect(self):
        """Establish connection to Redis."""
        if not self.enabled:
            return

        try:
            self.redis_client = await redis.from_url(
                self.redis_url,
                encoding="utf-8",
                decode_responses=True
            )
            # Test connection
            await self.redis_client.ping()
            logger.info("Redis cache connected successfully")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self.enabled = False
            self.redis_client = None

    async def disconnect(self):
        """Close Redis connection."""
        if self.redis_client:
            await self.redis_client.close()
            logger.info("Redis cache disconnected")

    def _make_key(self, key_type: str, user_id: UUID, suffix: str = "") -> str:
        """
        Generate Redis key with consistent naming.
        
        Args:
            key_type: Type of data (profile, events, metrics)
            user_id: User UUID
            suffix: Optional suffix for key
            
        Returns:
            Redis key string
        """
        base_key = f"klaviyo:{key_type}:{str(user_id)}"
        return f"{base_key}:{suffix}" if suffix else base_key

    async def get_cached_profile(
        self,
        user_id: UUID,
    ) -> Optional[dict[str, Any]]:
        """
        Get cached Klaviyo profile data.
        
        Args:
            user_id: User UUID
            
        Returns:
            Cached profile dict or None if not cached
        """
        if not self.enabled or not self.redis_client:
            return None

        try:
            key = self._make_key("profile", user_id)
            cached = await self.redis_client.get(key)
            
            if cached:
                logger.debug(f"Cache hit for profile {user_id}")
                return json.loads(cached)
            
            logger.debug(f"Cache miss for profile {user_id}")
            return None
            
        except Exception as e:
            logger.warning(f"Error getting cached profile: {e}")
            return None

    async def cache_profile(
        self,
        user_id: UUID,
        profile_data: dict[str, Any],
        ttl: Optional[int] = None,
    ) -> bool:
        """
        Cache Klaviyo profile data.
        
        Args:
            user_id: User UUID
            profile_data: Profile data to cache
            ttl: Time-to-live in seconds (uses default if not specified)
            
        Returns:
            True if cached successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            key = self._make_key("profile", user_id)
            ttl = ttl or self.default_ttl
            
            # Add cache metadata
            cached_data = {
                **profile_data,
                "_cached_at": datetime.utcnow().isoformat(),
                "_ttl": ttl,
            }
            
            await self.redis_client.setex(
                key,
                ttl,
                json.dumps(cached_data)
            )
            
            logger.debug(f"Cached profile for {user_id} (TTL: {ttl}s)")
            return True
            
        except Exception as e:
            logger.warning(f"Error caching profile: {e}")
            return False

    async def get_cached_event_metrics(
        self,
        user_id: UUID,
        event_name: str,
    ) -> Optional[dict[str, Any]]:
        """
        Get cached event metrics.
        
        Args:
            user_id: User UUID
            event_name: Event name (e.g., "Story Generated")
            
        Returns:
            Cached metrics dict or None
        """
        if not self.enabled or not self.redis_client:
            return None

        try:
            key = self._make_key("events", user_id, event_name)
            cached = await self.redis_client.get(key)
            
            if cached:
                logger.debug(f"Cache hit for events {user_id}:{event_name}")
                return json.loads(cached)
            
            return None
            
        except Exception as e:
            logger.warning(f"Error getting cached events: {e}")
            return None

    async def cache_event_metrics(
        self,
        user_id: UUID,
        event_name: str,
        metrics_data: dict[str, Any],
        ttl: Optional[int] = None,
    ) -> bool:
        """
        Cache event metrics data.
        
        Args:
            user_id: User UUID
            event_name: Event name
            metrics_data: Metrics data to cache
            ttl: Time-to-live in seconds
            
        Returns:
            True if cached successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            key = self._make_key("events", user_id, event_name)
            ttl = ttl or self.default_ttl
            
            cached_data = {
                **metrics_data,
                "_cached_at": datetime.utcnow().isoformat(),
            }
            
            await self.redis_client.setex(
                key,
                ttl,
                json.dumps(cached_data)
            )
            
            logger.debug(f"Cached events for {user_id}:{event_name}")
            return True
            
        except Exception as e:
            logger.warning(f"Error caching events: {e}")
            return False

    async def invalidate_profile(
        self,
        user_id: UUID,
    ) -> bool:
        """
        Invalidate cached profile data.
        
        Call this when profile is updated to ensure fresh data.
        
        Args:
            user_id: User UUID
            
        Returns:
            True if invalidated successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            key = self._make_key("profile", user_id)
            await self.redis_client.delete(key)
            logger.debug(f"Invalidated profile cache for {user_id}")
            return True
            
        except Exception as e:
            logger.warning(f"Error invalidating profile: {e}")
            return False

    async def invalidate_user_cache(
        self,
        user_id: UUID,
    ) -> bool:
        """
        Invalidate all cached data for a user.
        
        Args:
            user_id: User UUID
            
        Returns:
            True if invalidated successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            # Find all keys for this user
            pattern = f"klaviyo:*:{str(user_id)}*"
            keys = []
            
            async for key in self.redis_client.scan_iter(match=pattern):
                keys.append(key)
            
            if keys:
                await self.redis_client.delete(*keys)
                logger.debug(f"Invalidated {len(keys)} cache entries for {user_id}")
            
            return True
            
        except Exception as e:
            logger.warning(f"Error invalidating user cache: {e}")
            return False

    async def get_cache_stats(self) -> dict[str, Any]:
        """
        Get cache statistics.
        
        Returns:
            Dictionary with cache statistics
        """
        if not self.enabled or not self.redis_client:
            return {"enabled": False}

        try:
            info = await self.redis_client.info("stats")
            
            return {
                "enabled": True,
                "connected": True,
                "keyspace_hits": info.get("keyspace_hits", 0),
                "keyspace_misses": info.get("keyspace_misses", 0),
                "hit_rate": self._calculate_hit_rate(
                    info.get("keyspace_hits", 0),
                    info.get("keyspace_misses", 0)
                ),
            }
            
        except Exception as e:
            logger.warning(f"Error getting cache stats: {e}")
            return {"enabled": True, "connected": False, "error": str(e)}

    def _calculate_hit_rate(self, hits: int, misses: int) -> float:
        """Calculate cache hit rate percentage."""
        total = hits + misses
        if total == 0:
            return 0.0
        return round((hits / total) * 100, 2)

    async def cache_churn_risk(
        self,
        user_id: UUID,
        risk_score: float,
        ttl: int = 3600,  # 1 hour for churn predictions
    ) -> bool:
        """
        Cache churn risk score for a user.
        
        Args:
            user_id: User UUID
            risk_score: Churn risk score (0.0 to 1.0)
            ttl: Time-to-live in seconds
            
        Returns:
            True if cached successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            key = self._make_key("churn", user_id)
            
            data = {
                "risk_score": risk_score,
                "calculated_at": datetime.utcnow().isoformat(),
            }
            
            await self.redis_client.setex(
                key,
                ttl,
                json.dumps(data)
            )
            
            logger.debug(f"Cached churn risk for {user_id}: {risk_score}")
            return True
            
        except Exception as e:
            logger.warning(f"Error caching churn risk: {e}")
            return False

    async def get_cached_churn_risk(
        self,
        user_id: UUID,
    ) -> Optional[float]:
        """
        Get cached churn risk score.
        
        Args:
            user_id: User UUID
            
        Returns:
            Churn risk score or None if not cached
        """
        if not self.enabled or not self.redis_client:
            return None

        try:
            key = self._make_key("churn", user_id)
            cached = await self.redis_client.get(key)
            
            if cached:
                data = json.loads(cached)
                return data.get("risk_score")
            
            return None
            
        except Exception as e:
            logger.warning(f"Error getting cached churn risk: {e}")
            return None

    async def cache_adaptive_parameters(
        self,
        user_id: UUID,
        parameters: dict[str, Any],
        ttl: int = 600,  # 10 minutes
    ) -> bool:
        """
        Cache adaptive story parameters.
        
        Args:
            user_id: User UUID
            parameters: Adaptive parameters from adaptive engine
            ttl: Time-to-live in seconds
            
        Returns:
            True if cached successfully
        """
        if not self.enabled or not self.redis_client:
            return False

        try:
            key = self._make_key("adaptive", user_id)
            
            data = {
                **parameters,
                "_cached_at": datetime.utcnow().isoformat(),
            }
            
            await self.redis_client.setex(
                key,
                ttl,
                json.dumps(data)
            )
            
            logger.debug(f"Cached adaptive parameters for {user_id}")
            return True
            
        except Exception as e:
            logger.warning(f"Error caching adaptive parameters: {e}")
            return False

    async def get_cached_adaptive_parameters(
        self,
        user_id: UUID,
    ) -> Optional[dict[str, Any]]:
        """
        Get cached adaptive story parameters.
        
        Args:
            user_id: User UUID
            
        Returns:
            Cached parameters dict or None
        """
        if not self.enabled or not self.redis_client:
            return None

        try:
            key = self._make_key("adaptive", user_id)
            cached = await self.redis_client.get(key)
            
            if cached:
                logger.debug(f"Cache hit for adaptive parameters {user_id}")
                return json.loads(cached)
            
            return None
            
        except Exception as e:
            logger.warning(f"Error getting cached adaptive parameters: {e}")
            return None
