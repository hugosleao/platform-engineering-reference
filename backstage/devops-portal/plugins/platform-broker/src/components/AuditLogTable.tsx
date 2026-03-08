import React, { useEffect } from 'react';
import { Table, TableColumn, Progress } from '@backstage/core-components';
import { useAuditLog } from '../hooks/usePlatformBroker';
import { AuditEntry } from '../api/PlatformBrokerClient';

const columns: TableColumn<AuditEntry>[] = [
  { title: 'Ação', field: 'action' },
  { title: 'Recurso', field: 'resource' },
  { title: 'Responsável', field: 'actor' },
  { title: 'Status', field: 'status' },
  { title: 'Mensagem', field: 'message' },
  { title: 'Quando', field: 'timestamp' },
];

export function AuditLogTable() {
  const { entries, loading, refresh } = useAuditLog();

  useEffect(() => {
    refresh();
  }, []);

  if (loading) return <Progress />;

  return (
    <Table<AuditEntry>
      title="Audit Log — Platform Broker"
      options={{ pageSize: 20, search: true }}
      columns={columns}
      data={entries}
    />
  );
}
