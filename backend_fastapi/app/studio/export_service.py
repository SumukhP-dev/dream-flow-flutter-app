"""
Export service for Studio Website.

Handles exporting stories in various formats (PDF, Markdown, JSON).
"""

import json
import logging
from io import BytesIO
from uuid import UUID

from fastapi import HTTPException, Response

from ..shared.supabase_client import SupabaseClient

logger = logging.getLogger("dreamflow_studio.export_service")


class ExportService:
    """Service for exporting stories."""

    def __init__(self, supabase_client: SupabaseClient):
        """Initialize export service with Supabase client."""
        self.supabase = supabase_client

    def export_story(
        self,
        story_id: UUID,
        user_id: UUID,
        format: str,
        include_metadata: bool = True,
        include_media_links: bool = True,
    ) -> Response:
        """
        Export a story in the specified format.

        Args:
            story_id: UUID of the story
            user_id: UUID of the user (for authorization)
            format: Export format ('pdf', 'markdown', 'json')
            include_metadata: Whether to include metadata
            include_media_links: Whether to include media links

        Returns:
            Response with exported content
        """
        # Get story
        try:
            response = (
                self.supabase.client.table("stories")
                .select("*")
                .eq("id", str(story_id))
                .eq("user_id", str(user_id))
                .maybe_single()
                .execute()
            )
            if not response.data:
                raise HTTPException(status_code=404, detail="Story not found")
            story = response.data
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to get story: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to get story: {str(e)}"
            )

        # Export based on format
        if format == "json":
            return self._export_json(story, include_metadata, include_media_links)
        elif format == "markdown":
            return self._export_markdown(story, include_metadata, include_media_links)
        elif format == "pdf":
            return self._export_pdf(story, include_metadata, include_media_links)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported format: {format}")

    def _export_json(
        self,
        story: dict,
        include_metadata: bool,
        include_media_links: bool,
    ) -> Response:
        """Export story as JSON."""
        export_data = {
            "title": story["title"],
            "content": story["content"],
            "theme": story["theme"],
        }

        if include_metadata:
            export_data["metadata"] = {
                "id": story["id"],
                "created_at": story["created_at"],
                "updated_at": story["updated_at"],
                "parameters": story.get("parameters", {}),
            }

        if include_media_links:
            export_data["media"] = {}
            if story.get("video_url"):
                export_data["media"]["video"] = story["video_url"]
            if story.get("audio_url"):
                export_data["media"]["audio"] = story["audio_url"]

        json_str = json.dumps(export_data, indent=2, ensure_ascii=False)
        return Response(
            content=json_str.encode("utf-8"),
            media_type="application/json",
            headers={
                "Content-Disposition": f'attachment; filename="{story["title"]}.json"',
            },
        )

    def _export_markdown(
        self,
        story: dict,
        include_metadata: bool,
        include_media_links: bool,
    ) -> Response:
        """Export story as Markdown."""
        markdown_lines = [f"# {story['title']}", ""]

        if include_metadata:
            markdown_lines.extend(
                [
                    "## Metadata",
                    "",
                    f"- **ID**: {story['id']}",
                    f"- **Theme**: {story['theme']}",
                    f"- **Created**: {story['created_at']}",
                    f"- **Updated**: {story['updated_at']}",
                    "",
                ]
            )

        markdown_lines.extend(
            [
                "## Story",
                "",
                story["content"],
                "",
            ]
        )

        if include_media_links:
            media_lines = ["## Media", ""]
            if story.get("video_url"):
                media_lines.append(f"- [Video]({story['video_url']})")
            if story.get("audio_url"):
                media_lines.append(f"- [Audio]({story['audio_url']})")
            if media_lines:
                markdown_lines.extend(media_lines)

        markdown_str = "\n".join(markdown_lines)
        return Response(
            content=markdown_str.encode("utf-8"),
            media_type="text/markdown",
            headers={
                "Content-Disposition": f'attachment; filename="{story["title"]}.md"',
            },
        )

    def _export_pdf(
        self,
        story: dict,
        include_metadata: bool,
        include_media_links: bool,
    ) -> Response:
        """Export story as PDF."""
        try:
            from reportlab.lib.pagesizes import letter
            from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
            from reportlab.lib.units import inch
            from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer

            # Create PDF in memory
            buffer = BytesIO()
            doc = SimpleDocTemplate(buffer, pagesize=letter)
            story_content = []

            # Styles
            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                "CustomTitle",
                parent=styles["Heading1"],
                fontSize=24,
                spaceAfter=30,
            )

            # Add title
            story_content.append(Paragraph(story["title"], title_style))
            story_content.append(Spacer(1, 0.2 * inch))

            # Add metadata if requested
            if include_metadata:
                story_content.append(Paragraph("<b>Metadata</b>", styles["Heading2"]))
                story_content.append(Spacer(1, 0.1 * inch))
                story_content.append(
                    Paragraph(f"<b>Theme:</b> {story['theme']}", styles["Normal"])
                )
                story_content.append(
                    Paragraph(
                        f"<b>Created:</b> {story['created_at']}", styles["Normal"]
                    )
                )
                story_content.append(
                    Paragraph(
                        f"<b>Updated:</b> {story['updated_at']}", styles["Normal"]
                    )
                )
                story_content.append(Spacer(1, 0.2 * inch))

            # Add content
            story_content.append(Paragraph("<b>Story</b>", styles["Heading2"]))
            story_content.append(Spacer(1, 0.1 * inch))

            # Split content into paragraphs and add
            content_paragraphs = story["content"].split("\n\n")
            for para in content_paragraphs:
                if para.strip():
                    # Escape HTML and convert to Paragraph
                    story_content.append(
                        Paragraph(para.strip().replace("\n", "<br/>"), styles["Normal"])
                    )
                    story_content.append(Spacer(1, 0.1 * inch))

            # Add media links if requested
            if include_media_links:
                story_content.append(Spacer(1, 0.2 * inch))
                story_content.append(Paragraph("<b>Media</b>", styles["Heading2"]))
                story_content.append(Spacer(1, 0.1 * inch))
                if story.get("video_url"):
                    story_content.append(
                        Paragraph(f"Video: {story['video_url']}", styles["Normal"])
                    )
                if story.get("audio_url"):
                    story_content.append(
                        Paragraph(f"Audio: {story['audio_url']}", styles["Normal"])
                    )

            # Build PDF
            doc.build(story_content)

            # Get PDF bytes
            buffer.seek(0)
            pdf_bytes = buffer.read()
            buffer.close()

            return Response(
                content=pdf_bytes,
                media_type="application/pdf",
                headers={
                    "Content-Disposition": f'attachment; filename="{story["title"]}.pdf"',
                },
            )
        except ImportError:
            # Fallback to simple text if reportlab is not available
            logger.warning("reportlab not available, falling back to text export")
            text_content = f"{story['title']}\n\n{story['content']}"
            return Response(
                content=text_content.encode("utf-8"),
                media_type="text/plain",
                headers={
                    "Content-Disposition": f'attachment; filename="{story["title"]}.txt"',
                },
            )
        except Exception as e:
            logger.error(f"Failed to export PDF: {e}")
            raise HTTPException(
                status_code=500, detail=f"Failed to export PDF: {str(e)}"
            )
