"""
Klaviyo Catalog API integration for story themes.

This module treats story themes as "products" in Klaviyo's catalog system,
enabling product recommendations in emails and sophisticated theme analytics.
"""

import logging
from typing import Any, Optional
from datetime import datetime

logger = logging.getLogger("dream_flow")


class StoryCatalogSync:
    """
    Service for syncing story themes to Klaviyo Catalog API.
    
    This enables:
    - Theme recommendations in emails
    - Theme browsing/discovery campaigns
    - Theme performance analytics
    - Personalized theme suggestions based on purchase history
    """

    def __init__(self, klaviyo_service):
        """
        Initialize catalog sync service.
        
        Args:
            klaviyo_service: KlaviyoService or AsyncKlaviyoService instance
        """
        self.klaviyo_service = klaviyo_service
        self.catalog_type = "story_themes"

    async def sync_themes_to_klaviyo_catalog(
        self,
        themes: list[dict[str, Any]],
    ) -> bool:
        """
        Sync story themes to Klaviyo Catalog.
        
        Each theme becomes a catalog item that can be:
        - Recommended in emails
        - Tracked for "purchases" (story generations)
        - Analyzed for popularity and trends
        
        Args:
            themes: List of theme dictionaries with structure:
                {
                    "id": "theme_ocean",
                    "name": "Ocean Adventures",
                    "description": "Calming underwater stories",
                    "thumbnail": "https://cdn.dreamflow.com/themes/ocean.jpg",
                    "age_range": "3-8",
                    "energy_level": "calm",
                    "premium": false,
                    "tags": ["water", "animals", "exploration"]
                }
                
        Returns:
            True if sync succeeded
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            logger.warning("Klaviyo service not enabled for catalog sync")
            return False

        try:
            success_count = 0
            
            for theme in themes:
                success = await self._sync_single_theme(theme)
                if success:
                    success_count += 1
            
            logger.info(
                f"Synced {success_count}/{len(themes)} themes to Klaviyo Catalog"
            )
            
            return success_count == len(themes)
            
        except Exception as e:
            logger.error(f"Error syncing themes to catalog: {e}")
            return False

    async def _sync_single_theme(
        self,
        theme: dict[str, Any],
    ) -> bool:
        """
        Sync a single theme to Klaviyo Catalog.
        
        Args:
            theme: Theme dictionary
            
        Returns:
            True if synced successfully
        """
        try:
            # Build catalog item data
            catalog_item = {
                "data": {
                    "type": "catalog-item",
                    "attributes": {
                        "external_id": theme["id"],
                        "title": theme["name"],
                        "description": theme.get("description", ""),
                        "url": f"https://dreamflow.app/themes/{theme['id']}",
                        "image_full_url": theme.get("thumbnail", ""),
                        "published": True,
                        "custom_metadata": {
                            "age_range": theme.get("age_range", ""),
                            "energy_level": theme.get("energy_level", ""),
                            "premium": theme.get("premium", False),
                            "tags": theme.get("tags", []),
                        },
                    },
                },
                "relationships": {
                    "categories": {
                        "data": [
                            {
                                "type": "catalog-category",
                                "id": f"$custom:::category:::{theme.get('category', 'general')}",
                            }
                        ],
                    },
                },
            }
            
            # Use Klaviyo API to create/update catalog item
            if hasattr(self.klaviyo_service, '_make_request'):
                # Async version
                result = await self.klaviyo_service._make_request(
                    "POST",
                    f"/catalog-items",
                    catalog_item
                )
            else:
                # Sync version (would need implementation)
                logger.warning("Sync catalog API not implemented, skipping")
                return False
            
            logger.debug(f"Synced theme to catalog: {theme['name']}")
            return result is not None
            
        except Exception as e:
            logger.error(f"Error syncing theme {theme.get('id')}: {e}")
            return False

    async def track_theme_generation(
        self,
        user_id: str,
        email: str,
        theme_id: str,
        theme_name: str,
    ) -> bool:
        """
        Track when a user generates a story with a theme (like a "purchase").
        
        Args:
            user_id: User ID
            email: User email
            theme_id: Theme identifier
            theme_name: Theme name
            
        Returns:
            True if tracked successfully
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return False

        try:
            # Track as an Ordered Product event
            event_data = {
                "data": {
                    "type": "event",
                    "attributes": {
                        "metric": {
                            "data": {
                                "type": "metric",
                                "attributes": {
                                    "name": "Ordered Product",
                                },
                            },
                        },
                        "profile": {
                            "data": {
                                "type": "profile",
                                "attributes": {
                                    "email": email,
                                },
                            },
                        },
                        "properties": {
                            "$value": 0,  # Free for now, could be tier-based
                            "ItemNames": [theme_name],
                            "Items": [
                                {
                                    "ProductID": theme_id,
                                    "ProductName": theme_name,
                                    "Quantity": 1,
                                    "ItemPrice": 0,
                                    "RowTotal": 0,
                                    "ProductURL": f"https://dreamflow.app/themes/{theme_id}",
                                    "Categories": ["Story Themes"],
                                }
                            ],
                        },
                        "time": datetime.utcnow().isoformat(),
                    },
                },
            }
            
            if hasattr(self.klaviyo_service, '_make_request'):
                result = await self.klaviyo_service._make_request(
                    "POST",
                    "/events",
                    event_data
                )
                
                logger.debug(f"Tracked theme generation: {theme_name} for {email}")
                return result is not None
            
            return False
            
        except Exception as e:
            logger.error(f"Error tracking theme generation: {e}")
            return False

    async def get_recommended_themes(
        self,
        user_id: str,
        email: str,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """
        Get personalized theme recommendations for a user.
        
        This would typically use Klaviyo's recommendation engine,
        but we'll implement a simple version based on profile data.
        
        Args:
            user_id: User ID
            email: User email
            limit: Maximum number of recommendations
            
        Returns:
            List of recommended theme dictionaries
        """
        if not self.klaviyo_service:
            return []

        try:
            # Get user profile to understand preferences
            profile = None
            if hasattr(self.klaviyo_service, 'get_profile_metrics_async'):
                profile = await self.klaviyo_service.get_profile_metrics_async(
                    user_id, email
                )
            
            # In a full implementation, this would query Klaviyo's
            # recommendation API based on browsing/purchase history
            
            # For now, return sample recommendations
            recommendations = [
                {
                    "theme_id": "ocean_adventures",
                    "name": "Ocean Adventures",
                    "reason": "Popular with families like yours",
                    "confidence": 0.85,
                },
                {
                    "theme_id": "forest_friends",
                    "name": "Forest Friends",
                    "reason": "Calming themes you've enjoyed",
                    "confidence": 0.78,
                },
                {
                    "theme_id": "space_exploration",
                    "name": "Space Exploration",
                    "reason": "Trending this week",
                    "confidence": 0.72,
                },
            ]
            
            return recommendations[:limit]
            
        except Exception as e:
            logger.error(f"Error getting theme recommendations: {e}")
            return []

    async def create_theme_category(
        self,
        category_name: str,
        category_id: Optional[str] = None,
    ) -> Optional[str]:
        """
        Create a category for organizing themes in Klaviyo Catalog.
        
        Args:
            category_name: Name of the category (e.g., "Calming Themes")
            category_id: Optional external ID
            
        Returns:
            Category ID if created successfully
        """
        if not self.klaviyo_service or not self.klaviyo_service.enabled:
            return None

        try:
            category_id = category_id or category_name.lower().replace(" ", "_")
            
            category_data = {
                "data": {
                    "type": "catalog-category",
                    "attributes": {
                        "external_id": category_id,
                        "name": category_name,
                    },
                },
            }
            
            if hasattr(self.klaviyo_service, '_make_request'):
                result = await self.klaviyo_service._make_request(
                    "POST",
                    "/catalog-categories",
                    category_data
                )
                
                if result:
                    logger.info(f"Created theme category: {category_name}")
                    return category_id
            
            return None
            
        except Exception as e:
            logger.error(f"Error creating category: {e}")
            return None

    async def get_theme_analytics(
        self,
        theme_id: str,
        days: int = 30,
    ) -> Optional[dict[str, Any]]:
        """
        Get analytics for a specific theme.
        
        Args:
            theme_id: Theme identifier
            days: Number of days to analyze
            
        Returns:
            Dictionary with theme analytics
        """
        if not self.klaviyo_service:
            return None

        try:
            # Query Klaviyo for "Ordered Product" events with this theme
            # In full implementation, would use Metrics API
            
            analytics = {
                "theme_id": theme_id,
                "period_days": days,
                "total_generations": 0,  # Would query from Klaviyo
                "unique_users": 0,  # Would query from Klaviyo
                "completion_rate": 0.0,  # Would calculate from events
                "avg_rating": 0.0,  # Would query from feedback events
                "trending": False,  # Would compare to previous period
                "note": "Full analytics require Klaviyo Metrics API integration",
            }
            
            return analytics
            
        except Exception as e:
            logger.error(f"Error getting theme analytics: {e}")
            return None

    def get_default_themes(self) -> list[dict[str, Any]]:
        """
        Get default story themes for initial catalog sync.
        
        Returns:
            List of default theme dictionaries
        """
        return [
            {
                "id": "calm_focus",
                "name": "Calm Focus",
                "description": "Gentle stories to help children wind down and focus on sleep",
                "thumbnail": "https://cdn.dreamflow.com/themes/calm_focus.jpg",
                "age_range": "3-10",
                "energy_level": "very_calm",
                "premium": False,
                "tags": ["calming", "bedtime", "peaceful"],
                "category": "calming",
            },
            {
                "id": "ocean_adventures",
                "name": "Ocean Adventures",
                "description": "Explore the underwater world with friendly sea creatures",
                "thumbnail": "https://cdn.dreamflow.com/themes/ocean.jpg",
                "age_range": "4-10",
                "energy_level": "calm",
                "premium": False,
                "tags": ["ocean", "animals", "exploration", "water"],
                "category": "nature",
            },
            {
                "id": "forest_friends",
                "name": "Forest Friends",
                "description": "Meet woodland animals on peaceful forest adventures",
                "thumbnail": "https://cdn.dreamflow.com/themes/forest.jpg",
                "age_range": "3-8",
                "energy_level": "calm",
                "premium": False,
                "tags": ["forest", "animals", "nature"],
                "category": "nature",
            },
            {
                "id": "space_dreams",
                "name": "Space Dreams",
                "description": "Gentle journeys through the stars and planets",
                "thumbnail": "https://cdn.dreamflow.com/themes/space.jpg",
                "age_range": "5-10",
                "energy_level": "calm",
                "premium": True,
                "tags": ["space", "planets", "stars", "adventure"],
                "category": "adventure",
            },
            {
                "id": "magical_gardens",
                "name": "Magical Gardens",
                "description": "Discover enchanted flowers and friendly garden sprites",
                "thumbnail": "https://cdn.dreamflow.com/themes/garden.jpg",
                "age_range": "3-7",
                "energy_level": "very_calm",
                "premium": True,
                "tags": ["garden", "magic", "flowers", "peaceful"],
                "category": "fantasy",
            },
            {
                "id": "cozy_cabin",
                "name": "Cozy Cabin",
                "description": "Warm, comforting stories by the fireplace",
                "thumbnail": "https://cdn.dreamflow.com/themes/cabin.jpg",
                "age_range": "3-10",
                "energy_level": "very_calm",
                "premium": False,
                "tags": ["cozy", "comfort", "home", "warmth"],
                "category": "calming",
            },
        ]
