import { useApi } from '@backstage/core-plugin-api';
import { useState } from 'react';
import { platformBrokerApiRef, CreateServiceRequest, CreateServiceResponse } from '../api/PlatformBrokerClient';

export function useCreateService() {
  const api = useApi(platformBrokerApiRef);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | undefined>();
  const [result, setResult] = useState<CreateServiceResponse | undefined>();

  const execute = async (req: CreateServiceRequest) => {
    setLoading(true);
    setError(undefined);
    try {
      const res = await api.createService(req);
      setResult(res);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return { execute, loading, error, result };
}

export function useAuditLog() {
  const api = useApi(platformBrokerApiRef);
  const [entries, setEntries] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  const refresh = async () => {
    setLoading(true);
    try {
      const data = await api.listAudit();
      setEntries(data);
    } finally {
      setLoading(false);
    }
  };

  return { entries, loading, refresh };
}
