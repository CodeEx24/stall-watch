import styles from "./ProjectTable.module.css";

export function StalledBadge() {
  return (
    <span className={styles.stalled} data-testid="stalled-badge">
      Stalled
    </span>
  );
}
