def measurements(outage_at, recovered_at, last_restored_at):
    if recovered_at < outage_at or last_restored_at > outage_at:
        raise ValueError('Inconsistent recovery timestamps')
    return {
        'rto_seconds': round(recovered_at-outage_at,3),
        'rpo_seconds': round(outage_at-last_restored_at,3),
        'rpo_method': 'age of newest restored record at outage; includes idle time',
    }
