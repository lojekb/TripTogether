from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0007_notification'),
    ]

    operations = [
        migrations.AlterField(
            model_name='membership',
            name='role',
            field=models.CharField(
                choices=[
                    ('OWNER', 'Właściciel'),
                    ('ADMIN', 'Administrator'),
                    ('EDITOR', 'Uprawniony'),
                    ('MEMBER', 'Członek'),
                ],
                default='MEMBER',
                max_length=10,
            ),
        ),
        migrations.AlterField(
            model_name='notification',
            name='notification_type',
            field=models.CharField(
                choices=[
                    ('EVENT_UPDATED', 'Event updated'),
                    ('POLL_CREATED', 'Poll created'),
                    ('POLL_OPTION_ADDED', 'Poll option added'),
                    ('POLL_CLOSED', 'Poll closed'),
                    ('ROLE_CHANGED', 'Role changed'),
                ],
                max_length=32,
            ),
        ),
    ]
