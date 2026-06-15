from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('myapp', '0011_alter_ingredientrecepta_unitat'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='recepta',
            name='intolerancias',
        ),
        migrations.RemoveField(
            model_name='recepta',
            name='intolerancias_en',
        ),
    ]
