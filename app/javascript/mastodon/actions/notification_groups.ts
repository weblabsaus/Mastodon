import { apiFetchNotifications } from 'mastodon/api/notifications';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import type { ApiStatusJSON } from 'mastodon/api_types/statuses';
import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

import { importFetchedAccounts, importFetchedStatuses } from './importer';

export const fetchNotifications = createDataLoadingThunk(
  'notificationGroups/fetch',
  () => apiFetchNotifications(),
  (notifications, { dispatch }) => {
    const fetchedAccounts: ApiAccountJSON[] = [];
    const fetchedStatuses: ApiStatusJSON[] = [];

    notifications.forEach((notification) => {
      if ('sample_accounts' in notification) {
        fetchedAccounts.push(...notification.sample_accounts);
      }

      if (notification.type === 'admin.report') {
        fetchedAccounts.push(notification.report.target_account);
      }

      if (notification.type === 'moderation_warning') {
        fetchedAccounts.push(notification.moderation_warning.target_account);
      }

      if ('status' in notification) {
        fetchedStatuses.push(notification.status);
      }
    });

    if (fetchedAccounts.length > 0)
      dispatch(importFetchedAccounts(fetchedAccounts));

    if (fetchedStatuses.length > 0)
      dispatch(importFetchedStatuses(fetchedStatuses));

    // dispatch(submitMarkers());
  },
);
