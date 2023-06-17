import static com.android.aconfig.test.Flags.disabledRo;
import static com.android.aconfig.test.Flags.disabledRw;
import static com.android.aconfig.test.Flags.enabledRo;
import static com.android.aconfig.test.Flags.enabledRw;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class AconfigTest {
    @Test
    public void testDisabledReadOnlyFlag() {
        assertFalse(disabledRo());
    }

    @Test
    public void testEnabledReadOnlyFlag() {
        // TODO: change to assertTrue(enabledRo()) when the build supports reading tests/*.values
        // (currently all flags are assigned the default READ_ONLY + DISABLED)
        assertFalse(enabledRo());
    }

    @Test
    public void testDisabledReadWriteFlag() {
        assertFalse(disabledRw());
    }

    @Test
    public void testEnabledReadWriteFlag() {
        // TODO: change to assertTrue(enabledRw()) when the build supports reading tests/*.values
        // (currently all flags are assigned the default READ_ONLY + DISABLED)
        assertFalse(enabledRw());
    }
}
