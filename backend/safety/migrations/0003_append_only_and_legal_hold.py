"""Database-enforced rules, so no code path or admin can bypass them:

- SF-6: the moderation audit log is append-only (no UPDATE or DELETE).
- SF-9: a report on legal hold can't be deleted, and the hold can't be lifted by hand.
"""

from django.db import migrations

SQL = """
CREATE OR REPLACE FUNCTION safety_reject_change() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'safety_moderationaction is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER moderationaction_append_only
BEFORE UPDATE OR DELETE ON safety_moderationaction
FOR EACH ROW EXECUTE FUNCTION safety_reject_change();

CREATE OR REPLACE FUNCTION safety_protect_legal_hold() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' AND OLD.legal_hold THEN
    RAISE EXCEPTION 'report % is on legal hold and cannot be deleted', OLD.id;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.legal_hold AND NOT NEW.legal_hold THEN
    RAISE EXCEPTION 'legal hold on report % cannot be lifted', OLD.id;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER report_legal_hold
BEFORE UPDATE OR DELETE ON safety_report
FOR EACH ROW EXECUTE FUNCTION safety_protect_legal_hold();
"""

REVERSE = """
DROP TRIGGER IF EXISTS moderationaction_append_only ON safety_moderationaction;
DROP TRIGGER IF EXISTS report_legal_hold ON safety_report;
DROP FUNCTION IF EXISTS safety_reject_change();
DROP FUNCTION IF EXISTS safety_protect_legal_hold();
"""


class Migration(migrations.Migration):
    dependencies = [("safety", "0002_notice_report_moderationaction_and_more")]
    operations = [migrations.RunSQL(SQL, REVERSE)]
