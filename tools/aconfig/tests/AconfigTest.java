import static com.android.aconfig.test.Flags.disabled_ro;
import static com.android.aconfig.test.Flags.disabled_rw;
import static com.android.aconfig.test.Flags.enabled_ro;
import static com.android.aconfig.test.Flags.enabled_rw;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class AconfigTest {
    @Test
    public void testDisabledReadOnlyFlag() {
        assertFalse(disabled_ro());
    }

    @Test
    public void testEnabledReadOnlyFlag() {
        // TODO: change to assertTrue(enabled_ro()) when the build supports reading tests/*.values
        // (currently all flags are assigned the default READ_ONLY + DISABLED)
        assertFalse(enabled_ro());
    }

    @Test
    public void testDisabledReadWriteFlag() {
        assertFalse(disabled_rw());
    }

    @Test
    public void testEnabledReadWriteFlag() {
        // TODO: change to assertTrue(enabled_rw()) when the build supports reading tests/*.values
        // (currently all flags are assigned the default READ_ONLY + DISABLED)
        assertFalse(enabled_rw());
    }
}
