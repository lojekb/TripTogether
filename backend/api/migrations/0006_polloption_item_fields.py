from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0005_poll_polloption_vote'),
    ]

    operations = [
        migrations.AddField(
            model_name='polloption',
            name='item_type',
            field=models.CharField(
                choices=[
                    ('TRANSPORT', 'Transport'),
                    ('HOTEL', 'Nocleg'),
                    ('ATTRACTION', 'Atrakcja'),
                    ('OTHER', 'Inne'),
                ],
                default='OTHER',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='polloption',
            name='description',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='polloption',
            name='location_lat',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='polloption',
            name='location_lon',
            field=models.FloatField(blank=True, null=True),
        ),
    ]
