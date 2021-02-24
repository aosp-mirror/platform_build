/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.build.config;

import java.lang.reflect.Field;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Base class for reporting errors.
 */
public class ErrorReporter {
    /**
     * List of Entries that have occurred.
     */
    // Also used as the lock for this object.
    private final ArrayList<Entry> mEntries = new ArrayList();

    /**
     * The categories that are for this Errors object.
     */
    private Map<Integer, Category> mCategories;

    /**
     * Whether there has been a warning or an error yet.
     */
    private boolean mHadWarningOrError;

    /**
     * Whether there has been an error yet.
     */
    private boolean mHadError;

    public static class FatalException extends RuntimeException {
        FatalException(String message) {
            super(message);
        }

        FatalException(String message, Throwable chain) {
            super(message, chain);
        }
    }

    /**
     * Whether errors are errors, warnings or hidden.
     */
    public static enum Level {
        HIDDEN("hidden"),
        WARNING("warning"),
        ERROR("error");

        private final String mLabel;

        Level(String label) {
            mLabel = label;
        }

        String getLabel() {
            return mLabel;
        }
    }

    /**
     * The available error codes.
     */
    public class Category {
        private final int mCode;
        private boolean mIsLevelSettable;
        private Level mLevel;
        private String mHelp;

        /**
         * Construct a Category object.
         */
        public Category(int code, boolean isLevelSettable, Level level, String help) {
            if (!isLevelSettable && level != Level.ERROR) {
                throw new RuntimeException("Don't have WARNING or HIDDEN without isLevelSettable");
            }
            mCode = code;
            mIsLevelSettable = isLevelSettable;
            mLevel = level;
            mHelp = help;
        }

        /**
         * Get the numeric code for the Category, which can be used to set the level.
         */
        public int getCode() {
            return mCode;
        }

        /**
         * Get whether the level of this Category can be changed.
         */
        public boolean isLevelSettable() {
            return mIsLevelSettable;
        }

        /**
         * Set the level of this category.
         */
        public void setLevel(Level level) {
            if (!mIsLevelSettable) {
                throw new RuntimeException("Can't set level for error " + mCode);
            }
            mLevel = level;
        }

        /**
         * Return the level, including any overrides.
         */
        public Level getLevel() {
            return mLevel;
        }

        /**
         * Return the category's help text.
         */
        public String getHelp() {
            return mHelp;
        }

        /**
         * Add an error with no source position.
         */
        public void add(String message) {
            ErrorReporter.this.add(this, false, new Position(), message);
        }

        /**
         * Add an error.
         */
        public void add(Position pos, String message) {
            ErrorReporter.this.add(this, false, pos, message);
        }

        /**
         * Add an error with no source position, and throw a FatalException, stopping processing
         * immediately.
         */
        public void fatal(String message) {
            ErrorReporter.this.add(this, true, new Position(), message);
        }

        /**
         * Add an error, and throw a FatalException, stopping processing immediately.
         */
        public void fatal(Position pos, String message) {
            ErrorReporter.this.add(this, true, pos, message);
        }
    }

    /**
     * An instance of an error happening.
     */
    public static class Entry {
        private final Category mCategory;
        private final Position mPosition;
        private final String mMessage;

        Entry(Category category, Position position, String message) {
            mCategory = category;
            mPosition = position;
            mMessage = message;
        }

        public Category getCategory() {
            return mCategory;
        }

        public Position getPosition() {
            return mPosition;
        }

        public String getMessage() {
            return mMessage;
        }

        @Override
        public String toString() {
            return mPosition
                    + "[" + mCategory.getLevel().getLabel() + " " + mCategory.getCode() + "] "
                    + mMessage;
        }
    }

    private void initLocked() {
        if (mCategories == null) {
            HashMap<Integer, Category> categories = new HashMap();
            for (Field field: getClass().getFields()) {
                if (Category.class.isAssignableFrom(field.getType())) {
                    Category category = null;
                    try {
                        category = (Category)field.get(this);
                    } catch (IllegalAccessException ex) {
                        // Wrap and rethrow, this is always on this class, so it's
                        // our programming error if this happens.
                        throw new RuntimeException("Categories on Errors should be public.", ex);
                    }
                    Category prev = categories.put(category.getCode(), category);
                    if (prev != null) {
                        throw new RuntimeException("Duplicate categories with code "
                                + category.getCode());
                    }
                }
            }
            mCategories = Collections.unmodifiableMap(categories);
        }
    }

    /**
     * Returns a map of the category codes to the categories.
     */
    public Map<Integer, Category> getCategories() {
        synchronized (mEntries) {
            initLocked();
            return mCategories;
        }
    }

    /**
     * Add an error.
     */
    private void add(Category category, boolean fatal, Position pos, String message) {
        synchronized (mEntries) {
            initLocked();
            if (mCategories.get(category.getCode()) != category) {
                throw new RuntimeException("Errors.Category used from the wrong Errors object.");
            }
            final Entry entry = new Entry(category, pos, message);
            mEntries.add(entry);
            final Level level = category.getLevel();
            if (level == Level.WARNING || level == Level.ERROR) {
                mHadWarningOrError = true;
            }
            if (level == Level.ERROR) {
                mHadError = true;
            }
            if (fatal) {
                throw new FatalException(entry.toString());
            }
        }
    }

    /**
     * Returns whether there has been a warning or an error yet.
     */
    public boolean hadWarningOrError() {
        synchronized (mEntries) {
            return mHadWarningOrError;
        }
    }

    /**
     * Returns whether there has been an error yet.
     */
    public boolean hadError() {
        synchronized (mEntries) {
            return mHadError;
        }
    }

    /**
     * Returns a list of all entries that were added.
     */
    public List<Entry> getEntries() {
        synchronized (mEntries) {
            return new ArrayList<Entry>(mEntries);
        }
    }

    /**
     * Prints the errors.
     */
    public void printErrors(PrintStream out) {
        synchronized (mEntries) {
            for (Entry entry: mEntries) {
                if (entry.getCategory().getLevel() == Level.HIDDEN) {
                    continue;
                }
                out.println(entry.toString());
            }
        }
    }
}
