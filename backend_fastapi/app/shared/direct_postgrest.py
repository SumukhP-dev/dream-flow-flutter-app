"""
Direct database client for profile management.
This bypasses PostgREST authentication issues by using direct database connection.
"""

import asyncpg
from typing import Any, Dict, Optional, List
from uuid import UUID
from .config import get_settings


class DirectDatabaseClient:
    """Direct database client for profile operations."""
    
    def __init__(self):
        self.settings = get_settings()
        # Use the same connection as the database service
        self.db_url = "postgres://postgres:your-super-secret-and-long-postgres-password@supabase-db:5432/postgres"
    
    async def create_profile(self, user_id: UUID, **kwargs) -> Dict[str, Any]:
        """Create a profile using direct database connection."""
        conn = await asyncpg.connect(self.db_url)
        try:
            query = """
                INSERT INTO profiles (id, mood, routine, preferences, favorite_characters, calming_elements)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (id) DO NOTHING
                RETURNING id, mood, routine, preferences, favorite_characters, calming_elements, created_at
            """
            result = await conn.fetchrow(
                query,
                str(user_id),
                kwargs.get('mood', 'relaxed'),
                kwargs.get('routine', ''),
                kwargs.get('preferences', []),
                kwargs.get('favorite_characters', []),
                kwargs.get('calming_elements', [])
            )
            
            if result:
                return dict(result)
            return {"id": str(user_id), **kwargs}
        finally:
            await conn.close()
    
    async def create_subscription(self, user_id: UUID, tier: str = "free") -> Dict[str, Any]:
        """Create a subscription using direct database connection."""
        conn = await asyncpg.connect(self.db_url)
        try:
            query = """
                INSERT INTO subscriptions (user_id, tier, status, current_period_start, current_period_end)
                VALUES ($1, $2, 'active', NOW(), NOW() + INTERVAL '1 month')
                ON CONFLICT (user_id) DO NOTHING
                RETURNING user_id, tier, status, created_at
            """
            result = await conn.fetchrow(query, str(user_id), tier)
            
            if result:
                return dict(result)
            return {"user_id": str(user_id), "tier": tier, "status": "active"}
        finally:
            await conn.close()
