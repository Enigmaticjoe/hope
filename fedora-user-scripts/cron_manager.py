"""Manage user crontab entries for scheduled scripts."""

from crontab import CronTab

COMMENT_PREFIX = "fus:"


class CronManager:
    """Thin wrapper around python-crontab for Fedora User Scripts."""

    def __init__(self):
        self.cron = CronTab(user=True)

    def _comment(self, script_id: str) -> str:
        return f"{COMMENT_PREFIX}{script_id}"

    def get_schedule(self, script_id: str) -> str:
        """Return the cron expression for a script, or '' if unscheduled."""
        comment = self._comment(script_id)
        for job in self.cron:
            if job.comment == comment:
                return str(job.slices)
        return ""

    def set_schedule(
        self,
        script_id: str,
        name: str,
        script_path: str,
        cron_expr: str,
    ) -> None:
        """Create or update a cron job for the given script."""
        self.remove(script_id)
        job = self.cron.new(
            command=f"/bin/bash {script_path}  # {name}",
            comment=self._comment(script_id),
        )
        job.setall(cron_expr)
        self.cron.write()

    def remove(self, script_id: str) -> None:
        """Remove any cron job for the given script."""
        comment = self._comment(script_id)
        self.cron.remove_all(comment=comment)
        self.cron.write()
