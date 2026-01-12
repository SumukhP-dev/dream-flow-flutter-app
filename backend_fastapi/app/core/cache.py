"""
Simple in-memory cache for frequently used assets and theme combinations.
Can be replaced with Redis for production.
"""

import hashlib
import json
import time
from typing import Any, Optional
from functools import wraps


class SimpleCache:
    """Simple in-memory cache with TTL support."""
    
    def __init__(self, default_ttl: int = 3600):
        """
        Initialize cache.
        
        Args:
            default_ttl: Default time-to-live in seconds (1 hour)
        """
        self._cache: dict[str, tuple[Any, float]] = {}
        self.default_ttl = default_ttl
    
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache if not expired."""
        if key not in self._cache:
            return None
        
        value, expiry = self._cache[key]
        if time.time() > expiry:
            del self._cache[key]
            return None
        
        return value
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """Set value in cache with TTL."""
        ttl = ttl or self.default_ttl
        expiry = time.time() + ttl
        self._cache[key] = (value, expiry)
    
    def delete(self, key: str) -> None:
        """Delete key from cache."""
        if key in self._cache:
            del self._cache[key]
    
    def clear(self) -> None:
        """Clear all cache entries."""
        self._cache.clear()
    
    def cleanup_expired(self) -> None:
        """Remove expired entries."""
        now = time.time()
        expired_keys = [
            key for key, (_, expiry) in self._cache.items()
            if now > expiry
        ]
        for key in expired_keys:
            del self._cache[key]


# Global cache instance
_cache = SimpleCache(default_ttl=3600)  # 1 hour default


def get_cache_key(prefix: str, **kwargs) -> str:
    """Generate cache key from prefix and kwargs."""
    key_data = json.dumps(kwargs, sort_keys=True)
    key_hash = hashlib.md5(key_data.encode()).hexdigest()
    return f"{prefix}:{key_hash}"


def cached(ttl: int = 3600, key_prefix: str = "cache"):
    """
    Decorator to cache function results.
    
    Args:
        ttl: Time-to-live in seconds
        key_prefix: Prefix for cache keys
    """
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            cache_key = get_cache_key(
                f"{key_prefix}:{func.__name__}",
                args=args,
                kwargs=kwargs
            )
            
            # Check cache
            cached_value = _cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            
            # Call function and cache result
            result = await func(*args, **kwargs)
            _cache.set(cache_key, result, ttl)
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            cache_key = get_cache_key(
                f"{key_prefix}:{func.__name__}",
                args=args,
                kwargs=kwargs
            )
            
            # Check cache
            cached_value = _cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            
            # Call function and cache result
            result = func(*args, **kwargs)
            _cache.set(cache_key, result, ttl)
            return result
        
        # Return appropriate wrapper based on function type
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper
    
    return decorator


def get_cache() -> SimpleCache:
    """Get the global cache instance."""
    return _cache

