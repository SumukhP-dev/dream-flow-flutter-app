"""
A/B testing service for experiment tracking and assignment.
"""

import logging
import hashlib
import json
from typing import Optional, Dict, Any
from uuid import UUID
from datetime import datetime, timedelta

logger = logging.getLogger("dream_flow")


class ABTestingService:
    """Service for A/B testing and experiment tracking."""

    def __init__(self, supabase_client: Any):
        """
        Initialize A/B testing service.

        Args:
            supabase_client: Supabase client instance
        """
        self.client = supabase_client

    def assign_experiment(
        self,
        user_id: UUID,
        experiment_name: str,
        variants: list[str],
        weights: Optional[list[float]] = None,
    ) -> str:
        """
        Assign user to an experiment variant.

        Args:
            user_id: User ID
            experiment_name: Name of the experiment
            variants: List of variant names (e.g., ["control", "treatment"])
            weights: Optional weights for each variant (default: equal)

        Returns:
            Assigned variant name
        """
        if not weights:
            weights = [1.0 / len(variants)] * len(variants)

        if len(weights) != len(variants):
            raise ValueError("Weights and variants must have the same length")

        # Create deterministic assignment based on user_id and experiment_name
        # This ensures the same user always gets the same variant
        assignment_key = f"{experiment_name}:{user_id}"
        hash_value = int(hashlib.md5(assignment_key.encode()).hexdigest(), 16)
        
        # Normalize weights
        total_weight = sum(weights)
        normalized_weights = [w / total_weight for w in weights]
        
        # Assign variant based on hash
        cumulative = 0
        for i, (variant, weight) in enumerate(zip(variants, normalized_weights)):
            cumulative += weight
            if (hash_value % 10000) / 10000 < cumulative:
                assigned_variant = variant
                break
        else:
            # Fallback to last variant
            assigned_variant = variants[-1]

        # Store assignment
        try:
            assignment_data = {
                "user_id": str(user_id),
                "experiment_name": experiment_name,
                "variant": assigned_variant,
                "assigned_at": datetime.utcnow().isoformat(),
            }
            
            # Upsert assignment (update if exists)
            self.client.table("ab_test_assignments").upsert(
                assignment_data,
                on_conflict="user_id,experiment_name"
            ).execute()
        except Exception as e:
            logger.warning(f"Failed to store A/B test assignment: {e}")

        return assigned_variant

    def get_assignment(
        self,
        user_id: UUID,
        experiment_name: str,
    ) -> Optional[str]:
        """
        Get user's assigned variant for an experiment.

        Args:
            user_id: User ID
            experiment_name: Name of the experiment

        Returns:
            Variant name or None if not assigned
        """
        try:
            response = (
                self.client.table("ab_test_assignments")
                .select("variant")
                .eq("user_id", str(user_id))
                .eq("experiment_name", experiment_name)
                .maybe_single()
                .execute()
            )
            
            if response.data:
                return response.data.get("variant")
        except Exception as e:
            logger.warning(f"Failed to get A/B test assignment: {e}")
        
        return None

    def track_conversion(
        self,
        user_id: UUID,
        experiment_name: str,
        conversion_event: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Track a conversion event for an experiment.

        Args:
            user_id: User ID
            experiment_name: Name of the experiment
            conversion_event: Name of the conversion event (e.g., "subscription", "story_generated")
            metadata: Optional metadata dictionary
        """
        try:
            conversion_data = {
                "user_id": str(user_id),
                "experiment_name": experiment_name,
                "conversion_event": conversion_event,
                "metadata": json.dumps(metadata) if metadata else None,
                "converted_at": datetime.utcnow().isoformat(),
            }
            
            self.client.table("ab_test_conversions").insert(conversion_data).execute()
        except Exception as e:
            logger.warning(f"Failed to track A/B test conversion: {e}")

    def get_experiment_results(
        self,
        experiment_name: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """
        Get experiment results and conversion rates.

        Args:
            experiment_name: Name of the experiment
            start_date: Start date for analysis (optional)
            end_date: End date for analysis (optional)

        Returns:
            Dictionary with experiment results
        """
        try:
            # Get all assignments
            query = (
                self.client.table("ab_test_assignments")
                .select("*")
                .eq("experiment_name", experiment_name)
            )
            
            if start_date:
                query = query.gte("assigned_at", start_date.isoformat())
            if end_date:
                query = query.lte("assigned_at", end_date.isoformat())
            
            assignments_response = query.execute()
            assignments = assignments_response.data if assignments_response.data else []

            # Get all conversions
            conversions_query = (
                self.client.table("ab_test_conversions")
                .select("*")
                .eq("experiment_name", experiment_name)
            )
            
            if start_date:
                conversions_query = conversions_query.gte("converted_at", start_date.isoformat())
            if end_date:
                conversions_query = conversions_query.lte("converted_at", end_date.isoformat())
            
            conversions_response = conversions_query.execute()
            conversions = conversions_response.data if conversions_response.data else []

            # Calculate metrics per variant
            variant_stats: Dict[str, Dict[str, Any]] = {}
            
            for assignment in assignments:
                variant = assignment.get("variant")
                user_id = assignment.get("user_id")
                
                if variant not in variant_stats:
                    variant_stats[variant] = {
                        "assignments": 0,
                        "conversions": 0,
                        "conversion_rate": 0.0,
                    }
                
                variant_stats[variant]["assignments"] += 1
                
                # Count conversions for this user
                user_conversions = [
                    c for c in conversions
                    if c.get("user_id") == user_id
                ]
                variant_stats[variant]["conversions"] += len(user_conversions)
            
            # Calculate conversion rates
            for variant, stats in variant_stats.items():
                if stats["assignments"] > 0:
                    stats["conversion_rate"] = (
                        stats["conversions"] / stats["assignments"]
                    ) * 100

            return {
                "experiment_name": experiment_name,
                "period": {
                    "start": start_date.isoformat() if start_date else None,
                    "end": end_date.isoformat() if end_date else None,
                },
                "variants": variant_stats,
                "total_assignments": len(assignments),
                "total_conversions": len(conversions),
            }
        except Exception as e:
            logger.error(f"Failed to get experiment results: {e}", exc_info=True)
            raise

