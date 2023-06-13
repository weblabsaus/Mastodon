import { CircularProgress } from './circle_progress';

export const LoadingIndicator: React.FC = () => (
  <div className='loading-indicator'>
    <CircularProgress size={50} strokeWidth={6} />
  </div>
);
